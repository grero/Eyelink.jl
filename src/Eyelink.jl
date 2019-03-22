__precompile__()
module Eyelink
using FileIO
using HDF5
using ProgressMeter
using LegacyStrings
include("types.jl")
include("calib.jl")
const bytestring = LegacyStrings.bytestring

if Sys.isapple()
    const _library = "/Library/Frameworks/edfapi.framework/Versions/Current/edfapi"
else
    const _library = "/usr/lib/libedfapi.so"
end

function version()
	_version = ccall((:edf_get_version, _library), Ptr{UInt8}, ())
	return bytestring(_version)
end

function edfopen(fname::String,consistency_check::Int64, load_events::Bool, load_samples::Bool)
	err = 0
	if !isfile(fname)
		error("Could not open file $fname")
		return nothing
	end
    f = ccall((:edf_open_file, _library),Ptr{Nothing}, (Ptr{UInt8}, Int64, Int64, Int64,Ptr{Int64}),fname,consistency_check,load_events,load_samples,Ref(err))
	if err != 0
		error("Could not open file $fname")
		return nothing
	end
	edffile = EDFFile(fname,f)
	finalizer(edfclose, edffile)
	return edffile
end

function edfclose(f::EDFFile)
    if f.ptr != C_NULL
        err = ccall((:edf_close_file, _library), Int64, (Ptr{Nothing},),f.ptr)
        f.ptr = C_NULL
    end
end

function edfload(edffile::EDFFile)
	f = edffile
	#samples = Samples(0)
    nevents = get_element_count(f)
    samples = Array{FSAMPLE}(undef, nevents)
    events = Array{Event}(undef, nevents)
    event_count = 0
    sample_count = 0
    total_count = 0
    p = Progress(nevents, 0.1)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :sample_type
			_sample = edfdata(f)
            sample_count += 1
            samples[sample_count] = _sample

		elseif nextevent == :recording_info
			#nothing
		elseif nextevent == :no_pending_items
			#ntohing
		else #event
			_event = edfdata(f)
            event_count += 1
            if event_count <= nevents
                events[event_count] = Event(_event)
            else
                push!(events, Event(_event))
            end
		end
        total_count += 1
        update!(p, total_count)
	end
    Dict([("events", events[1:event_count]), ("samples", samples[1:sample_count])])
end

function get_element_count(edffile::EDFFile)
    nelements = 0
    if edffile.ptr != C_NULL
        nelements = ccall((:edf_get_element_count, _library), Int64, (Ptr{Nothing},), edffile.ptr)
    end
    nelements
end
"""
Load eyelink events and, optionally, samples from the EDF file `f`. First checks whether parsed versions of samples and events exist, and loads those, before attempting to lead the entire EDF file.

	function load(f::String,check=1, load_events=true,load_samples=true)
"""
function load(f::String;check=1, load_events=true,load_samples=true,do_save=true)
	samplefile = replace(f, ".edf" => "_eyesamples.hdf5")
	if isfile(samplefile) && load_samples
        ss = load(File(format"HDF5", samplefile))
		edffile = edfopen(f, check, true, false)
		data = edfload(edffile)
		eyedata = EyelinkData(data["events"],ss)
	else
		edffile = edfopen(f, check, load_events, load_samples)
		data = edfload(edffile)
		if load_samples
			ss = Samples(data["samples"])
            if do_save
                save(FileIO.File(format"HDF5", samplefile), ss)
            end
		else
			ss = Samples(0)
		end
		eyedata = EyelinkData(data["events"], ss)
	end
	eyedata
end

function save(f::FileIO.File{FileIO.DataFormat{:HDF5}}, samples::Samples)
    HDF5.h5open(f.filename,"w") do ff
        for _f in fieldnames(Samples)
            ff[string(_f)] = getfield(samples, _f)
            flush(ff)
        end
    end
end

function load(f::FileIO.File{FileIO.DataFormat{:HDF5}})
    samples = HDF5.h5open(f.filename, "r") do ff
        nsamples = size(ff["gx"],2)
        samples = Samples(nsamples)
        for _f in fieldnames(Samples)
            X = getfield(samples, _f)
            Y = read(ff, string(_f))
            X .= Y
        end
        samples
    end
    samples
 end

function edfnextdata!(f::EDFFile)
	eventtype = ccall((:edf_get_next_data, _library), Int64, (Ptr{Nothing},), f.ptr)
	f.nextevent =  get(datatypes,eventtype,:unknown)
	return f.nextevent
end

function edfdata(f::EDFFile)
	_data = ccall((:edf_get_float_data, _library), Ptr{Nothing}, (Ptr{Nothing},), f.ptr)
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
    messages = Array{String}(0)
    timestamps = Array{Int64}(0)
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
    saccades = Array{Saccade}(0)
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
    saccades = Array{Saccade}(0)
	for _event in events
		if _event.eventtype == :endsacc
			push!(saccades, Saccade(float(_event.sttime), float(_event.entime), _event.gstx, _event.gsty, _event.genx, _event.geny,0))
		end
	end
	saccades
end

function getgazepos(f::String;check_consistency=0)
    edffile = edfopen(f, check_consistency, false, true)
    try
        return getgazepos(edffile)
    catch ee
        rethrow(ee)
    finally
        edfclose(edffile)
    end
end

function getgazepos(f::EDFFile)
    n = get_element_count(f)
    gazex = Matrix{Float32}(undef, 2,n)
    gazey = Matrix{Float32}(undef, 2,n)
    timestamp = Vector{Int64}(undef, n)
    i = 1
    p = Progress(n, 0.1)
    while f.nextevent != :nopending
        nextevent = edfnextdata!(f)
        if nextevent == :sample_type
            _sample = edfdata(f)
            gazex[1,i] = _sample.gx[1]
            gazex[2,i] = _sample.gx[2]
            gazey[1,i] = _sample.gy[1]
            gazey[2,i] = _sample.gy[2]
            timestamp[i] = _sample.time
            i += 1
            update!(p, i)
        end
    end
    gazex[:,1:i-1], gazey[:,1:i-1], timestamp[1:i]
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
    events = Array{EyeEvent}(0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :endfix
			verbose > 0 && "Found fixation event"
			push!(events, getfixation(edfdata(f)))
		end
	end
	events
end

"""
Return the screen size as (width, height) in pixels
"""
function getscreensize(f::EDFFile;verbose::Integer=0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :messageevent
			msg,t = getmessage(edfdata(f))
			if contains(msg, "DISPLAY_COORDS")
				pp = split(strip(msg,'\0'))
				return parse(Int64,pp[end-1])+1,parse(Int64,pp[end])+1
			end
		end
	end
end

function parsetrials(fname::String,args...)
    f = edfopen(fname, 1, true, true)
    parsetrials(f,args...)
end

function parsetrials(f::EDFFile)
	trialstart = "00000000"
	parsetrials(f, trialstart)
end

function parsetrials(f::EDFFile,trialmarker::String)
	trialidx = 0
	trialevent = :none
	firstsaccade = false
    saccades = Array{AlignedSaccade}(0)
    trialindex = Array{Int64}(0)
    correct = Array{Bool}(0)
    distractor_row = Array{Int64}(0)
    distractor_col = Array{Int64}(0)
    target_row = Array{Int64}(0)
    target_col = Array{Int64}(0)
    messages = Array{String}(0)
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

function parsetrials(fnames::Array{String,1},args...)
    eyelinkdata = parsetrials(fnames[1],args...)
    for f in fnames[2:end]
      _eyelinkdata = parsetrials(f,args...)
      append!(eyelinkdata, _eyelinkdata)
    end
    eyelinkdata
end


"""
Return the x and y coordinates of the saccade end points. Note that y = 0 corresponds to the top of the screen
"""
function get_saccade_position(saccades::Array{T,1}) where T <: AbstractSaccade
	n = length(saccades)
  x = Vector{Float64}(undef, n)
  y = Vector{Float64}(undef, n)
	for (i,saccade) in enumerate(saccades)
		x[i] = saccade.end_x
		y[i] = saccade.end_y
	end
	x,y
end

end #module
