import Base.zero, Base.isempty, Base.+

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
        time::Uint32
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
        flags::Uint16
        input::Uint16
        buttons::Uint16
        htype::Int16
        errors::Uint16
end
