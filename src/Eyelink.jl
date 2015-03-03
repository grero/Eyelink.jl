module Eyelink
const _library = "/Library/Frameworks/edfapi.framework/Versions/Current/edfapi"

function version()
	_version = ccall((:edf_get_version, _library), Ptr{Uint8}, ())
	return bytestring(_version)
end

end #module
