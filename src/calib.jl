"""
Return the validation points and errors.
"""
function get_validation(data::EyelinkData)
    val_msg = filter(ee->occursin("VALIDATE", ee.message), data.events)

    rpos = r"at ([0-9]*),([0-9]*)"
    rpix = r"([0-9.\-]*),([0-9.\-]*) pix"
    cal_pos = fill(0.0, 2, length(val_msg))
    cal_err = fill(0.0, 2, length(val_msg))
    for (ii,mm) in enumerate(val_msg)
        mpos = match(rpos, mm.message)
        if mpos.match != nothing
            cal_pos[1,ii] = parse(Float64, mpos[1])
            cal_pos[2,ii] = parse(Float64, mpos[2])
        end
        mpix = match(rpix, mm.message)
        if mpix != nothing
            cal_err[1,ii] = parse(Float64, mpix[1])
            cal_err[2,ii] = parse(Float64, mpix[2])
        end 
    end
    cal_pos, cal_err
end
