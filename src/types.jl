import Base.zero, Base.isempty, Base.+
import FileIO
import MAT
import FileIO.save

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
             200 => :sample_type)


type EDFFile
	fname::AbstractString
	ptr::Ptr{Void}
	nevents::Int64
	nsamples::Int64
	nextevent::Symbol
end

function EDFFile(fname::AbstractString, ptr::Ptr)
	EDFFile(fname,ptr,0,0,:unknown)
end

type EyeEvent
	time::Int64
	x::Float32
	y::Float32
end

abstract AbstractSaccade

type Saccade <: AbstractSaccade
	time::Float64
	start_x::Float32
	start_y::Float32
	end_x::Float32
	end_y::Float32
	trialindex::Int64
end

type AlignedSaccade <: AbstractSaccade
	time::Float64
	start_x::Float32
	start_y::Float32
	end_x::Float32
	end_y::Float32
	trialindex::Int64
	alignment::Symbol
end

+(s::Saccade, t::Real) = Saccade(s.time + t, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex)
+(s::AlignedSaccade, t::Real) = AlignedSaccade(s.time + t, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex, s.alignment)

function Saccade(s::AlignedSaccade)
	Saccade(s.time, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex)
end

function Saccade(s::AlignedSaccade,t0::Real)
	Saccade(s.time + t0, s.start_x, s.start_y, s.end_x, s.end_y, s.trialindex)
end

function gettime{T<:AbstractSaccade}(S::Array{T,1})
	time = zeros(length(S))
	for (i,s) in enumerate(S)
		time[i] = s.time
	end
	return time
end

function zero(::Type{Saccade})
	return Saccade(0, 0.0, 0.0, 0.0, 0.0)
end

function zero(::Type{AlignedSaccade})
	return AlignedSaccade(0, 0.0, 0.0, 0.0, 0.0,:unknown)
end

isempty{T<:AbstractSaccade}(S::T) = S.start_x == S.end_x & S.start_y == S.end_y

type LSTRING
	len::Int16
	c::UInt8
end

type FEVENT
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

immutable float_vec2
    x1::Float32
    x2::Float32
end

immutable int_vec2
    x1::Int16
    x2::Int16
end

immutable int_vec8
    x1::Int16
    x2::Int16
    x3::Int16
    x4::Int16
    x5::Int16
    x6::Int16
    x7::Int16
    x8::Int16
end


type FSAMPLE
        time::UInt32
        #px::Array{Float32,1}
        px::float_vec2
        py::float_vec2
        hx::float_vec2
        hy::float_vec2
        pa::float_vec2
        gx::float_vec2
        gy::float_vec2
        rx::Float32
        ry::Float32
        gxvel::float_vec2
        gyvel::float_vec2
        hxvel::float_vec2
        hyvel::float_vec2
        rxvel::float_vec2
        ryvel::float_vec2
        fgxvel::float_vec2
        fgyvel::float_vec2
        fhxvel::float_vec2
        fhyvel::float_vec2
        frxvel::float_vec2
        fryvel::float_vec2
        hdata::int_vec8
        flags::UInt16
        input::UInt16
        buttons::UInt16
        htype::Int16
        errors::UInt16
end

function save{T<:AbstractSaccade}(f::FileIO.File{FileIO.DataFormat{:MAT}},saccades::Array{T,1})
    n = length(saccades)
    _time = Array(Float64,n)
    _start_x = Array(Float64,n)
    _start_y = Array(Float64,n)
    _end_x = Array(Float64,n)
    _end_y = Array(Float64,n)
    _trialindex = Array(Int64,n)
    if T <: AlignedSaccade
        _alignment = Array(ASCIIString,n)
    end
    for (i,s) in enumerate(saccades)
        _time[i] = s.time
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
    D["time"] = _time
    D["start_x"] = _start_x
    D["start_y"] = _start_y
    D["end_x"] = _end_x
    D["end_y"] = _end_y
    D["trialindex"] = _trialindex
    if T <: AlignedSaccade
        D["alignment"] = _alignment
    end
    MAT.matwrite(f.filename,D)
end

function load(f::FileIO.File{FileIO.DataFormat{:MAT}})
    M = MAT.matread(f.filename)
    n = length(M["time"])
    if "alignment" in keys(M)
        saccades = Array(AlignedSaccade,n)
    else
        saccades = Array(Saccade,n)
    end
    for i in 1:n
        _time = M["time"][i]
        _start_x = M["start_x"][i]
        _start_y = M["start_y"][i]
        _end_x = M["end_x"][i]
        _end_y = M["end_y"][i]
        _trialindex = M["trialindex"][i]
        if eltype(saccades) <: AlignedSaccade
            _alignment = M["alignment"][i]
            saccades[i] = AlignedSaccade(_time,_start_x, _start_y, _end_x, _end_y, _trialindex, _alignment)
        else
            saccades[i] = Saccade(_time,_start_x, _start_y, _end_x, _end_y, _trialindex)
        end
    end
    saccades
end
