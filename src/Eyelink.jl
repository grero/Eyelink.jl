module Eyelink
using Docile
@docstrings
include("types.jl")
include("plot.jl")

const _library = "/Library/Frameworks/edfapi.framework/Versions/Current/edfapi"


function version()
	_version = ccall((:edf_get_version, _library), Ptr{Uint8}, ())
	return bytestring(_version)
end

function edfopen(fname::String,consistency_check::Int64, load_events::Bool, load_samples::Bool)
	err = 0
	if !isfile(fname)
		error("Could not open file $fname")
		return nothing
	end
	f = ccall((:edf_open_file, _library),Ptr{Void}, (Ptr{Uint8}, Int64, Int64, Int64,Ptr{Int64}),fname,consistency_check,load_events,load_samples,&err)
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

function edfnextdata!(f::EDFFile) 
	eventtype = ccall((:edf_get_next_data, _library), Int64, (Ptr{Void},), f.ptr)
	f.nextevent =  get(datatypes,eventtype,:unknown)
	return f.nextevent
end

function edfdata(f::EDFFile)
	_data = ccall((:edf_get_float_data, _library), Ptr{Void}, (Ptr{Void},), f.ptr)
	if f.nextevent == :sample_type
	elseif f.nextevent == :recording_info
	elseif f.nextevent == :no_pending_items
	else
		#even type
		_event = unsafe_load(convert(Ptr{FEVENT}, _data), 1)
		return _event
	end
end

function getmessage(event::FEVENT)
	if get(datatypes,event.eventtype,:unknown) == :messageevent
		return bytestring(convert(Ptr{Uint8}, event.message + sizeof(Uint16)), unsafe_load(convert(Ptr{Uint16}, event.message)))
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

@doc meta("Return the screen size as (width, height) in pixels", return_type=(Int64, Int64))->
function getscreensize(f::EDFFile;verbose::Integer=0)
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		if nextevent == :messageevent
			msg = getmessage(edfdata(f))
			if contains(msg, "DISPLAY_COORDS")
				pp = split(strip(msg,'\0'))
				return int(pp[end-1])+1,int(pp[end])+1
			end
		end
	end
end

function parsetrials(f::EDFFile)
	trialstart = "00000000"
	parsetrials(f, trialstart)
end

function parsetrials(f::EDFFile,trialmarker::String)
	trialidx = 0
	trialevent = :none
	firstsaccade = false
	saccades = Array(AlignedSaccade,0)
	trialindex = Array(Int64,0)
	trialstart = 0
	while f.nextevent != :nopending
		nextevent = edfnextdata!(f)
		_event= edfdata(f)
		if nextevent == :messageevent
			message = getmessage(_event)
			#check what the message is
			m = message[1:3:end]
			if m == trialmarker #trial start
				trialevent = :trialstart
				trialidx +=1
				firstsaccade = false
				trialstart = _event.sttime
			elseif m == "00000101" #response
				trialevent = :response
			elseif m == "00100000" #trial end
				trialevent = :none
				#if we are at the end and have seen no saccade, insert an empty one
				#if !firstsaccade
				#	push!(saccades, zero(Saccade))
				#end
			end
		elseif nextevent == :endsacc && trialevent != :none

			#if !firstsaccade
			#	firstsaccade = true
			push!(saccades, AlignedSaccade(float(_event.sttime-trialstart), _event.gstx, _event.gsty, 
				  _event.genx, _event.geny,trialidx,:trialstart))
		     push!(trialindex,trialidx)
			# end

		end
	end
	return saccades,trialindex
end

@doc meta("Return the x and y coordinates of the saccade end points. Note that y = 0 corresponds to the top of the screen")->
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
