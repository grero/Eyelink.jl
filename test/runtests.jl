using Eyelink
using Test


@testset "Validation Points" begin
    messages = readlines(joinpath(@__DIR__, "testdata.txt"))
    cal_pos, cal_err = Eyelink.get_validation(messages)
    @test cal_pos[1,:] ≈ [960.0,960.0, 960.0,115.0,1805.0,217.0,1703.0, 217.0,1703.0]
    @test cal_pos[2,:] ≈ [600.0,102.0,1098.0,600.0,600.0,162.0,162.0,1038.0,1038.0]
    @test cal_err[1,:] ≈ [1.4, -12.1,  -1.0, 17.7, -7.5,  2.9, -15.1, -19.6, -14.5]
    @test cal_err[2,:] ≈ [ -15.3, -3.6, -20.3, 3.7, 23.5, -0.2,  3.0, -15.0,  0.5]
end

@testset "Load file" begin
    download("http://cortex.nus.edu.sg/testdata/w7_10_2.edf", "w7_10_2.edf")
    eyelinkdata = Eyelink.load("w7_10_2.edf")
    @test eyelinkdata.recording_info[1].time == 0x001c0657
    @test eyelinkdata.recording_info[1].state == 0x01
    @test eyelinkdata.recording_info[2].time == 0x001c07f9
    @test eyelinkdata.recording_info[2].state == 0x00
    mm = eyelinkdata.events[1].message
    @test mm == "DISPLAY_COORDS 0 0 1920 1200"
    start_fix_events = filter(ee->ee.eventtype==:endfix,eyelinkdata.events)
    @test length(start_fix_events) == 3
    @test start_fix_events[1].sttime == 0x001c065e
    @test start_fix_events[2].sttime == 0x001c06fa
    @test start_fix_events[3].sttime == 0x001c076e

    end_fix_events = filter(ee->ee.eventtype==:endfix,eyelinkdata.events)
    @test length(end_fix_events) == 3
    input_events = filter(ee->ee.eventtype==:inputevent,eyelinkdata.events)
    @test length(input_events) == 2
    @test input_events[1].sttime == 0x001c0657
    @test input_events[2].sttime == 0x001c07f9

    gx = eyelinkdata.samples.gx[2,1]
    @test gx ≈ 846.2f0
    gy = eyelinkdata.samples.gy[2,1]
    @test gy ≈ 643.5f0
    gazex,gazey,gtime = Eyelink.getgazepos("w7_10_2.edf")
    @test size(gazex) == size(eyelinkdata.samples.gx)
    @test size(gazey) == size(eyelinkdata.samples.gy)
    @test gazex ≈ eyelinkdata.samples.gx
    @test gazey ≈ eyelinkdata.samples.gy
    messages, timestamps = Eyelink.getmessages("w7_10_2.edf")
    message_events = filter(ee->ee.eventtype==:messageevent,eyelinkdata.events)
    _messages = [m.message for m in message_events]
    _timestamps = [m.sttime for m in message_events]
    @test messages == _messages
    @test timestamps == _timestamps
    screen_width, screen_height = Eyelink.getscreensize("w7_10_2.edf")
    @test screen_width == 1920
    @test screen_height == 1200

    @testset "Saccades" begin
        saccade_events = filter(ee->ee.eventtype==:endsacc,eyelinkdata.events)
        saccades = Eyelink.getsaccades("w7_10_2.edf")
        @test length(saccades) == length(saccade_events)
        start_time = round(UInt32, saccades[1].start_time)
        end_time = round(UInt32, saccades[1].end_time)
        @test start_time == saccade_events[1].sttime
        @test end_time == saccade_events[1].entime
    end
    @testset "Fixations" begin
        fixation_events = filter(ee->ee.eventtype==:endfix, eyelinkdata.events)
        fixations = Eyelink.getfixations("w7_10_2.edf")
        @test length(fixation_events) == length(fixations)
        @test fixation_events[1].sttime == round(UInt32, fixations[1].time)
    end
end
