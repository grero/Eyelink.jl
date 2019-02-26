"""
Return the validation points and errors.
"""
function get_validation(data::Eyelink.EyelinkData)
    val_events = filter(ee->occursin("VALIDATE", ee.message), data.events)
    messages = [ee.message for ee in val_events]
    get_validation(messages)
end

function get_validation(messages::Vector{String})
    _messages = filter(mm->occursin("VALIDATE", mm), messages)
    rpos = r"at ([0-9]*),([0-9]*)"
    rpix = r"([0-9.\-]*),([0-9.\-]*) pix"
    cal_pos = fill(0.0, 2, length(_messages))
    cal_err = fill(0.0, 2, length(_messages))
    for (ii,mm) in enumerate(_messages)
        mpos = match(rpos, mm)
        if mpos.match != nothing
            cal_pos[1,ii] = parse(Float64, mpos[1])
            cal_pos[2,ii] = parse(Float64, mpos[2])
        end
        mpix = match(rpix, mm)
        if mpix != nothing
            cal_err[1,ii] = parse(Float64, mpix[1])
            cal_err[2,ii] = parse(Float64, mpix[2])
        end 
    end
    cal_pos, cal_err
end
