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
    ll = length(eyelinkdata.events)
    @show ll
    @test ll == 32
    sttime = [ee.sttime for ee in eyelinkdata.events[1:30]]
    hh = hash(sttime)
    @test hh == 0x963b31f9fdfdb0fa
    mm = eyelinkdata.events[1].message
    @test mm == "DISPLAY_COORDS 0 0 1920 1200"
    tt = eyelinkdata.events[30].eventtype
    @test tt == :inputevent
    gx = eyelinkdata.samples.gx[2,1]
    @test gx ≈ 846.2f0
    gy = eyelinkdata.samples.gy[2,1]
    @test gy ≈ 643.5f0
end
