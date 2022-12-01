
function show_version_number(vn::VersionNumber)::String
    io = IOBuffer()
    print(io, vn)
    return String(take!(io))
end
