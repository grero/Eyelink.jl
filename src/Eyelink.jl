module Eyelink
include("types.jl")
include("plot.jl")

const _library = "/Library/Frameworks/edfapi.framework/Versions/Current/edfapi"


function version()
	_version = ccall((:edf_get_version, _library), Ptr{Uint8}, ())
	return bytestring(_version)
end

function edfopen(fname::String,consistency_check::Int64, load_events::Bool, load_samples::Bool)
	err = 0
	f = ccall((:edf_open_file, _library),Ptr{Void}, (Ptr{Uint8}, Int64, Int64, Int64,Ptr{Int64}),fname,consistency_check,load_events,load_samples,&err)
	if err != 0
		error("Could not open file $fname")
		return nothing
	end
	return EDFFile(fname,f) 
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


end #module
