"""
GenX: An Configurable Capacity Expansion Model
Copyright (C) 2021,  Massachusetts Institute of Technology
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
A complete copy of the GNU General Public License v2 (GPLv2) is available
in LICENSE.txt.  Users uncompressing this from an archive may not have
received this license file.  If not, see <http://www.gnu.org/licenses/>.
"""

@doc raw"""
    load_maximum_rate_build!(path::AbstractString, inputs::Dict, setup::Dict)

Read input parameters related to a maximum capacity rate (either in absolute terms MW or rate growth %)
"""
function load_maximum_rate_build!(path::AbstractString, inputs::Dict, setup::Dict)
    filename = "Maximum_build_rate.csv"
    df = DataFrame(CSV.File(joinpath(path, filename), header=true), copycols=true)
    NumberOfMaxBuildRates = length(df[!,:MaxRateBuildConstraint])
    inputs["NumberOfMaxBuildRates"] = NumberOfMaxBuildRates
    inputs["MaxBuildMW"] = df[!,:Max_MW]
    inputs["MaxBuildRate"] = df[!,:Max_Rate]
    if setup["ParameterScale"] == 1
        inputs["MaxBuildMW"] /= ModelScalingFactor # Convert to GW
    end
    println(filename * " Successfully Read!")
end
