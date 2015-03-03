module Eyelink
include("plot.jl")

const _library = "/Library/Frameworks/edfapi.framework/Versions/Current/edfapi"

datatypes = {0 => :nopending,
			24 => :messageevent, 
			 25 => :buttonevent,
			 5 => :startsacc , 
			 6 => :endsacc, 
			 7 => :startfix, 
			 8 => :endfix,
			 28 => :inputevent,
			 15 => :startsamples,
			 16 => :endsamples,
			 17 => :startevent,
			 18	=> :endevent}


type EDFFile
	fname::String
	ptr::Ptr{Void}
	nevents::Int64
	nsamples::Int64
	nextevent::Symbol
end

function EDFFile(fname::String, ptr::Ptr)
	EDFFile(fname,ptr,0,0,:unknown)
end

type EyeEvent
	time::Int64
	x::Float32
	y::Float32
end

type LSTRING
	len::Int16
	c::Uint8
end

type FEVENT
	time::Uint32
	eventtype::Int16
	read::Uint16
	sttime::Uint32
	entime::Uint32
	hstx::Float32
	hsty::Float32
	gstx::Float32
	gsty::Float32
	sta::Float32
	henx::Float32
	heny::Float32
	genx::Float32
	geny::Float32
	ena::Float32
	havx::Float32
	havy::Float32
	gavx::Float32
	gavy::Float32
	ava::Float32
	avel::Float32
	pvel::Float32
	svel::Float32
	evel::Float32
	supdx::Float32
	eupdx::Float32
	supdy::Float32
	eupdy::Float32

	eye::Int16
	status::Uint16
	flags::Uint16
	input::Uint16
	buttons::Uint16
	parsedby::Uint16
	message::Ptr{LSTRING}
end

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
