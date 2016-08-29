module Eyelink
import GUICheck
using Docile
using Compat
using FileIO,JLD
@docstrings
include("types.jl")

if GUICheck.hasgui()
	include("plot.jl")
end

const _library = "/Library/Frameworks/edfapi.framework/Versions/Current/edfapi"


function version()
	_version = ccall((:edf_get_version, _library), Ptr{UInt8}, ())
	return bytestring(_version)
end

function edfopen(fname::ASCIIString,consistency_check::Int64, load_events::Bool, load_samples::Bool)
	err = 0
	if !isfile(fname)
		error("Could not open file $fname")
		return nothing
	end
	f = ccall((:edf_open_file, _library),Ptr{Void}, (Ptr{UInt8}, Int64, Int64, Int64,Ptr{Int64}),fname,consistency_check,load_events,load_samples,&err)
	if err != 0
		error("Could not open file $fname")
		return nothing
	end
	edffile = EDFFile(fname,f) 
	finalizer(edffile, edfclose)
	return edffile 
end

function edfclose(f::EDFFile)
	err = ccall((:edf_close_file, _library), Int64, (Ptr{Void},),f.ptr)
	if err != 0
		error("Could not close file $(EDFFile.fname)")
	end
end

function edfload(edffile::EDFFile)
	f = edffile
	#samples = Samples(0) 
	samples = Array(FSAMPLE,0)
	events = Array(Event,0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :sample_type
			_sample = edfdata(f)
			push!(samples, _sample)

		elseif nextevent == :recording_info
			#nothing
		elseif nextevent == :no_pending_items
			#ntohing
		else #event
			_event = edfdata(f)
			push!(events, Event(_event))
		end
	end
	Dict([("events", events), ("samples", samples)])
end

function load(f::AbstractString,check=1, load_events=true,load_samples=true)
	_path,_ext = splitdir(f)
	samplefile = joinpath(_path, "eyesamples.jd")
	if isfile(samplefile)
		ss = JLD.load(samplefile, "ss")
		edffile = edfopen(f, check, true, false)
		data = edfload(edffile)
		eyedata = EyelinkData(data["events"],ss)
	else
		edffile = edfopen(f, check, true, true)
		data = edfload(edffile)
		ss = Samples(data["samples"])
		JLD.save(FileIO.File(format"JLD", samplefile), Dict([("ss", ss)]))
		eyedata = EyelinkData(data["events"], ss)
	end
	eyedata
end

function save(f::FileIO.File{FileIO.DataFormat{:JLD}},events::Array{Event,1}, samples::Array{FSAMPLE,1}) 
	ss = Samples(samples)
	JLD.save(f, EyelinkData(events,ss))
end

function edfnextdata!(f::EDFFile) 
	eventtype = ccall((:edf_get_next_data, _library), Int64, (Ptr{Void},), f.ptr)
	f.nextevent =  get(datatypes,eventtype,:unknown)
	return f.nextevent
end

function edfdata(f::EDFFile)
	_data = ccall((:edf_get_float_data, _library), Ptr{Void}, (Ptr{Void},), f.ptr)
	if f.nextevent == :sample_type
		#TODO: Implement this
		_sample = unsafe_load(convert(Ptr{FSAMPLE}, _data), 1)
                return _sample
	elseif f.nextevent == :recording_info
	elseif f.nextevent == :no_pending_items
	else
		#even type
		_event = unsafe_load(convert(Ptr{FEVENT}, _data), 1)
		return _event
	end
end

function getmessages(f::EDFFile)
	messages = Array(AbstractString,0)
        timestamps = Array(Int64,0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :messageevent
                        message,timestamp = getmessage(edfdata(f))
			push!(messages, strip(message,'\0'))
                        push!(timestamps,timestamp)
		end
	end
	messages,timestamps
end

function getsaccades(f::EDFFile)
	saccades = Array(Saccade, 0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		_event= edfdata(f)
		if nextevent == :endsacc
			push!(saccades, Saccade(float(_event.sttime), float(_event.entime), _event.gstx, _event.gsty, _event.genx, _event.geny,0))
		end
	end
	saccades
end

function getsaccades(events::Array{Event,1})
	saccades = Array(Saccade, 0)
	for ee in events
		if ee.eventtype == :endsacc
			push!(saccades, Saccade(float(_event.sttime), float(_event.entime), _event.gstx, _event.gsty, _event.genx, _event.geny,0))
		end
	end
	saccades
end

function getgazepos(f::EDFFile)
    gazex = Array(Float32,0)
    gazey = Array(Float32,0)
    timestamp = Array(Int64,0)
    while f.nextevent != :nopending
        nextevent = edfnextdata!(f)
        if nextevent == :sample_type
            _sample = edfdata(f)
            push!(gazex, _sample.gx.x1)
            push!(gazex, _sample.gx.x2)
            push!(gazey, _sample.gy.x1)
            push!(gazey, _sample.gy.x2)
            push!(timestamp, _sample.time)
        end
    end
    reshape(gazex,(2,div(length(gazex),2))), reshape(gazey, (2, div(length(gazey),2))), timestamp
end

function getmessage(event::FEVENT)
	if get(datatypes,event.eventtype,:unknown) == :messageevent
		return bytestring(convert(Ptr{UInt8}, event.message + sizeof(UInt16)), unsafe_load(convert(Ptr{UInt16}, event.message))), event.sttime
	end
end

function getfixation(event::FEVENT)
	if get(datatypes,event.eventtype,:unknown) == :endfix
		return EyeEvent(convert(Int64,event.sttime), event.gavx, event.gavy)
	end
end

function getfixations(f::EDFFile;verbose::Integer=0)
	events = Array(EyeEvent,0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :endfix
			verbose > 0 && "Found fixation event"
			push!(events, getfixation(edfdata(f)))
		end
	end
	events
end

Docile.@doc meta("Return the screen size as (width, height) in pixels", return_type=(Int64, Int64))->
function getscreensize(f::EDFFile;verbose::Integer=0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :messageevent
			msg,t = getmessage(edfdata(f))
			if contains(msg, "DISPLAY_COORDS")
				pp = split(strip(msg,'\0'))
				return int(pp[end-1])+1,int(pp[end])+1
			end
		end
	end
end

function parsetrials(fname::ASCIIString,args...)
    f = edfopen(fname, 1, true, true)
    parsetrials(f,args...)
end

function parsetrials(f::EDFFile)
	trialstart = "00000000"
	parsetrials(f, trialstart)
end

function parsetrials(f::EDFFile,trialmarker::AbstractString)
	trialidx = 0
	trialevent = :none
	firstsaccade = false
	saccades = Array(AlignedSaccade,0)
	trialindex = Array(Int64,0)
	correct = Array(Bool,0)
    distractor_row = Array(Int64,0)
    distractor_col = Array(Int64,0)
    target_row = Array(Int64,0)
    target_col = Array(Int64,0)
    messages = Array(ASCIIString,0)
	trialstart = 0
    d_row = 0
    d_col = 0
    t_row = 0
    t_col = 0
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		_event= edfdata(f)
		if nextevent == :messageevent
			message,tt = getmessage(_event)
            push!(messages,message)
			#check what the message is
			m = message[1:3:end]
			if m == trialmarker #trial start
				trialevent = :trialstart
				trialidx +=1
				firstsaccade = false
				trialstart = _event.sttime
                                push!(correct, false)
                                push!(distractor_row,0)
                                push!(distractor_col,0)
                                push!(target_row,0)
                                push!(target_col,0)
			elseif m == "00000101" #response
                            trialevent = :response
                        elseif m == "00000110" #reward
                            correct[trialidx] = true
			elseif m == "00100000" #trial end
				trialevent = :none
				#if we are at the end and have seen no saccade, insert an empty one
				#if !firstsaccade
				#	push!(saccades, zero(Saccade))
				#end
                                d_row = 0
                                d_col = 0
                                t_row = 0
                                t_col = 0
                        elseif m[1] == '1' && m[2] == '0'
                            if length(m) == 8
                                d_row = parse(Int,m[8:-1:6],2)
                                d_col = parse(Int,m[5:-1:3],2)
                            elseif length(m) == 14
                                d_row = parse(Int,m[end:-1:9],2)
                                d_col = parse(Int,m[8:-1:3],2)
                            end
                            distractor_row[trialidx] = d_row
                            distractor_col[trialidx] = d_col
                        elseif m[1] == '0' && m[2] == '1'
                            if length(m) == 8
                                t_row = parse(Int,m[8:-1:6],2)
                                t_col = parse(Int,m[5:-1:3],2)
                            elseif length(m) == 14
                                t_row = parse(Int,m[end:-1:9],2)
                                t_col = parse(Int,m[8:-1:3],2)
                            end
                            target_row[trialidx] = t_row
                            target_col[trialidx] = t_col
			end
		elseif nextevent == :endsacc && trialevent != :none
            if _event.sttime > trialstart
                push!(saccades, AlignedSaccade(float(_event.sttime)-float(trialstart), float(_event.entime) -float(trialstart),_event.gstx, _event.gsty, _event.genx, _event.geny,trialidx,:start))
                 push!(trialindex,trialidx)
			end

		end
	end
    return EyelinkTrialData(saccades,trialindex, correct,target_row, target_col, distractor_row, distractor_col,messages)
end

function parsetrials(fnames::Array{ASCIIString,1},args...)
    eyelinkdata = parsetrials(fnames[1],args...)
    for f in fnames[2:end]
        _eyelinkdata = parsetrials(f,args...)
        append!(eyelinkdata, _eyelinkdata)
    end
    eyelinkdata
end


Docile.@doc meta("Return the x and y coordinates of the saccade end points. Note that y = 0 corresponds to the top of the screen")->
function get_saccade_position{T<:AbstractSaccade}(saccades::Array{T,1})
	n = length(saccades)
	x = Array(Float64,n)
	y = Array(Float64,n)
	for (i,saccade) in enumerate(saccades) 
		x[i] = saccade.end_x 
		y[i] = saccade.end_y 
	end
	x,y
end

end #module
