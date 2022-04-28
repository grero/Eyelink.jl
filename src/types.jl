import Base.zero, Base.isempty, Base.+, Base.convert, Base.append!, Base.push!
import FileIO
import MAT
import FileIO.save
using StaticArrays

datatypes = Dict{Int16, Symbol}(0 => :nopending,
			24 => :messageevent,
			 25 => :buttonevent,
			 5 => :startsacc,
			 6 => :endsacc,
			 7 => :startfix,
			 8 => :endfix,
			 28 => :inputevent,
			 15 => :startsamples,
			 16 => :endsamples,
			 17 => :startevent,
			 18 => :endevent,
             30 => :recordinginfo,
             200 => :sample_type)


mutable struct EDFFile
	fname::String
	ptr::Ptr{Nothing}
	nevents::Int64
	nsamples::Int64
	nextevent::Symbol
end

function EDFFile(fname::String, ptr::Ptr)
	EDFFile(fname,ptr,0,0,:unknown)
end

struct Recording
    time::UInt32
    sample_rate::Float32
    eflags::UInt16
    sflags::UInt16
    state::UInt8
    record_type::UInt8
    pupil_type::UInt8
    recording_mode::UInt8
    filter_type::UInt8
    pos_type::UInt8
    eye::UInt8
end

function Recording()
    args = []
    for f in fieldnames(Recording)
        tt = fieldtype(Recording,f)
        push!(args, zero(tt))
    end
    Recording(args...)
end

struct EyeEvent
	time::Int64
	x::Float32
	y::Float32
end

abstract type AbstractSaccade end

struct Saccade <: AbstractSaccade
	start_time::Float64
	end_time::Float64
	start_x::Float32
	start_y::Float32
	end_x::Float32
	end_y::Float32
	trialindex::Int64
end

Saccade(time::Float64, start_x, start_y, end_x, end_y, trialindex) = Saccade(time, 0.0, start_x, start_y, end_x, end_y, trialindex)

struct AlignedSaccade <: AbstractSaccade
	start_time::Float64
	end_time::Float64
	start_x::Float32
	start_y::Float32
	end_x::Float32
	end_y::Float32
	trialindex::Int64
	alignment::Symbol
end

AlignedSaccade(time, start_x, start_y, end_x, end_y, trialindex, alignment) = AlignedSaccade(time, 0.0, start_x, start_y, end_y, end_y, trialindex, alignment)

+(s::Saccade, t::Real) = Saccade(s.time + t, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex)
+(s::AlignedSaccade, t::Real) = AlignedSaccade(s.time + t, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex, s.alignment)

function Saccade(s::AlignedSaccade)
	Saccade(s.start_time, s.end_time, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex)
end

function Saccade(s::AlignedSaccade,t0::Real)
	Saccade(s.start_time + t0, s.end_time + t0, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex)
end

function AlignedSaccade(s::Saccade, t0::Real, alignment::Symbol)
	AlignedSaccade(s.start_time -t0, s.end_time-t0, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex, alignment)
end

function gettime(S::Array{T,1}) where T<:AbstractSaccade
	time = zeros(length(S))
	for (i,s) in enumerate(S)
		time[i] = s.start_time
	end
	return time
end

function zero(::Type{Saccade})
	return Saccade(0, 0.0, 0.0, 0.0, 0.0)
end

function zero(::Type{AlignedSaccade})
	return AlignedSaccade(0, 0.0, 0.0, 0.0, 0.0,:unknown)
end

isempty(S::T) where T<:AbstractSaccade = S.start_x == S.end_x & S.start_y == S.end_y

struct EyelinkTrialData
    saccades::Array{AlignedSaccade,1}
    trialindex::Array{Int64,1}
    correct::Array{Bool,1}
    target_row::Array{Int64,1}
    target_col::Array{Int64,1}
    distractor_row::Array{Int64,1}
    distractor_col::Array{Int64,1}
    messages::Array{String,1}
		timestamps::Array{Int64,1}
end

EyelinkTrialData(saccades, trialindex, correct, target_row, target_col, distractor_row, distractor_col, messages) = EyelinkTrialData(saccades, trialindex, correct, target_row, target_col, distractor_row, distractor_col, messages, zeros(Int64,length(messages)))

function append!(data1::EyelinkTrialData, data2::EyelinkTrialData)
    for s in data2.saccades
        s2 = deepcopy(s)
        s2.trialindex += data1.trialindex[end] #make sure we update the trialindex
        push!(data1.saccades,s2)
    end
    append!(data1.trialindex, data2.trialindex + data1.trialindex[end])
    append!(data1.correct, data2.correct)
    append!(data1.target_row, data2.target_row)
    append!(data1.target_col, data2.target_col)
    append!(data1.distractor_row, data2.distractor_row)
    append!(data1.distractor_col, data2.distractor_col)
    append!(data1.messages, data2.messages)
end

struct Event
	time::UInt32
	sttime::UInt32
	entime::UInt32
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
	message::String
	eventtype::Symbol
end

function Base.show(io::IO, ::MIME"text/plain", events::Vector{Event})
	Δt = (events[end].time - events[1].time)/1000.0
	n = length(events)
	print(io, "Vector of $n Events spanning $(Δt)s")
end

struct LSTRING
	len::Int16
	c::UInt8
end

struct FEVENT
	time::UInt32
	eventtype::Int16
	read::UInt16
	sttime::UInt32
	entime::UInt32
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
	status::UInt16
	flags::UInt16
	input::UInt16
	buttons::UInt16
	parsedby::UInt16
	message::Ptr{LSTRING}
end

function Event(fevent::FEVENT)
	eventtype = get(datatypes,fevent.eventtype,:none)
	if eventtype == :messageevent
		message,tt = getmessage(fevent)
	else
		message = ""
	end
	args = Any[]
	for ff in setdiff(fieldnames(Event), [:message, :eventtype])
		push!(args,getfield(fevent,ff))
	end
	push!(args, strip(message, '\0'))
	push!(args, eventtype)
	Event(args...)
end

struct FSAMPLE
        time::UInt32
        px::SVector{2,Float32}
        py::SVector{2,Float32}
        hx::SVector{2,Float32}
        hy::SVector{2,Float32}
        pa::SVector{2,Float32}
        gx::SVector{2,Float32}
        gy::SVector{2,Float32}
        rx::Float32
        ry::Float32
        gxvel::SVector{2,Float32}
        gyvel::SVector{2,Float32}
        hxvel::SVector{2,Float32}
        hyvel::SVector{2,Float32}
        rxvel::SVector{2,Float32}
        ryvel::SVector{2,Float32}
        fgxvel::SVector{2,Float32}
        fgyvel::SVector{2,Float32}
        fhxvel::SVector{2,Float32}
        fhyvel::SVector{2,Float32}
        frxvel::SVector{2,Float32}
        fryvel::SVector{2,Float32}
        hdata::SVector{8,Int16}
        flags::UInt16
        input::UInt16
        buttons::UInt16
        htype::Int16
        errors::UInt16
end

#TODO: Just learn macros already...
function FSAMPLE()
  args = []
  for f in fieldnames(FSAMPLE)
    q = fieldtype(FSAMPLE, f)
    push!(args, "zero($(q))")
  end
  eval(parse("Eyelink.FSAMPLE($(join(args,",")))"))
end

struct Samples
	time::Array{UInt32,1}
	px::Array{Float32,2}
	py::Array{Float32,2}
	hx::Array{Float32,2}
	hy::Array{Float32,2}
	pa::Array{Float32,2}
	gx::Array{Float32,2}
	gy::Array{Float32,2}
	rx::Array{Float32,1}
	ry::Array{Float32,1}
	gxvel::Array{Float32,2}
	gyvel::Array{Float32,2}
	hxvel::Array{Float32,2}
	hyvel::Array{Float32,2}
	rxvel::Array{Float32,2}
	ryvel::Array{Float32,2}
	fgxvel::Array{Float32,2}
	fgyvel::Array{Float32,2}
	fhxvel::Array{Float32,2}
	fhyvel::Array{Float32,2}
	frxvel::Array{Float32,2}
	fryvel::Array{Float32,2}
end

function Samples(n::Integer)
	args = Any[]
	for ff in fieldnames(Samples)
		if fieldtype(Samples, ff) <: Array{Float32,2}
			push!(args, zeros(2,n))
		else
			push!(args, fieldtype(Samples, ff)(undef, n))
		end
	end
	Samples(args...)
end

function Samples(fsamples::Array{FSAMPLE,1})
	samples = Samples(length(fsamples))
	_fieldnames = fieldnames(Samples)
	for i in 1:length(fsamples)
		for ff in _fieldnames
			if fieldtype(FSAMPLE, ff) <: SVector{2,Float32}
				qq = getfield(fsamples[i],ff)
				getfield(samples, ff)[:,i] = qq
			else
				getfield(samples,ff)[i] = getfield(fsamples[i],ff)
			end
		end
	end
	samples
end

function push!(samples::Samples, fsample::FSAMPLE)
    qq = Array{Float32}(2)
	for ff in fieldnames(samples)
		if fieldtype(FSAMPLE, ff) <: SVector{2,Float32}
			qq = getfield(fsample,ff)
			push!(getfield(samples,ff), qq)
		else
			push!(getfield(samples,ff), getfield(fsample,ff))
		end
	end
end


function save(f::FileIO.File{FileIO.DataFormat{:MAT}},saccades::Array{T,1}) where T<:AbstractSaccade
    D = convert(Dict, saccades)
    MAT.matwrite(f.filename,D)
end

function load(f::FileIO.File{FileIO.DataFormat{:MAT}})
    M = MAT.matread(f.filename)
    if "alignment" in keys(M)
        saccades = convert(Array{AlignedSaccade,1}, M)
    else
        saccades = convert(Array{Saccade,1}, M)
    end
    saccades
end

function convert(::Type{Dict}, saccades::Array{T,1}) where T<:AbstractSaccade
    n = length(saccades)
    _start_time = Array{Float64}(n)
    _end_time = Array{Float64}(n)
    _start_x = Array{Float64}(n)
    _start_y = Array{Float64}(n)
    _end_x = Array{Float64}(n)
    _end_y = Array{Float64}(n)
    _trialindex = Array{Int64}(n)
    if T <: AlignedSaccade
        _alignment = Array{String}(n)
    end
    for (i,s) in enumerate(saccades)
        _start_time[i] = s.start_time
		_end_time[i] = s.end_time
        _start_x[i] = s.start_x
        _start_y[i] = s.start_y
        _end_x[i] = s.end_x
        _end_y[i] = s.end_y
        _trialindex[i] = s.trialindex
        if T <: AlignedSaccade
            _alignment[i] = string(s.alignment)
        end
    end
    D = Dict()
    D["start_time"] = _start_time
	D["end_time"] = _end_time
    D["start_x"] = _start_x
    D["start_y"] = _start_y
    D["end_x"] = _end_x
    D["end_y"] = _end_y
    D["trialindex"] = _trialindex
    if T <: AlignedSaccade
        D["alignment"] = _alignment
    end
    D
end

function convert(::Type{Array{T,1}}, M::Dict) where T<:AbstractSaccade
		if "time" in keys(M)
			n = length(M["time"])
		elseif "start_time" in keys(M)
			n = length(M["start_time"])
		else
			throw(ArgumentError("No valid objects of type $T found"))
		end
    if "alignment" in keys(M)
        saccades = Array{AlignedSaccade}(n)
    else
        saccades = Array{Saccade}(n)
    end
    for i in 1:n
				if "start_time" in keys(M)
					start_time = M["start_time"][i]
					end_time = M["end_time"][i]
				else
					start_time = M["time"][i]
					end_time = 0.0
				end
        _start_x = M["start_x"][i]
        _start_y = M["start_y"][i]
        _end_x = M["end_x"][i]
        _end_y = M["end_y"][i]
        _trialindex = M["trialindex"][i]
        if eltype(saccades) <: AlignedSaccade
            _alignment = M["alignment"][i]
						saccades[i] = AlignedSaccade(start_time, end_time, _start_x, _start_y, _end_x, _end_y, _trialindex, _alignment)
        else
					saccades[i] = Saccade(start_time,end_time, _start_x, _start_y, _end_x, _end_y, _trialindex)
        end
    end
    saccades
end

struct EyelinkData
    recording_info::Vector{Recording}
	events::Array{Event,1}
	samples::Samples
end

function Base.show(io::IO, edata::EyelinkData)
	nevents = length(edata.events)
	nsamples = size(edata.samples.gx,2)
	print(io, "EyelinkData with $(nevents) events and $(nsamples) samples")
end

Eyelinkdata(events::Vector{Event}, samples::Samples) = EyelinkData([Reording()], events, samples)

get_gaze(eyelinkdata::EyelinkData) = (eyelinkdata.samples.gx, eyelinkdata.samples.gy)
get_pupil(eyelinkdata::EyelinkData) = eyelinkdata.samples.pa
