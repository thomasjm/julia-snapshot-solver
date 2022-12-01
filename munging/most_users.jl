
import Pkg
Pkg.activate(".")

import JSON
import PkgDeps
using TOML: parsefile


nameToCount = Dict()

registry = parsefile("/home/tom/tools/General/Registry.toml")
for (uuid, info) in registry["packages"]
    name = info["name"]

    numUsers = length(PkgDeps.users(name))
    println("$name\t$numUsers")

    nameToCount[name] = numUsers
end

open("name_to_count.json", "w") do file
    write(file, JSON.json(nameToCount))
end
