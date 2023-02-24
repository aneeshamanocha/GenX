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
	maximum_build_rate!(EP::Model, inputs::Dict, setup::Dict)
The maximum build rate constraint allows for modeling a maximum build rate for each resource.
"""

function maximum_build_rate!(EP::Model, inputs::Dict, setup::Dict)

	println("Maximum Build Rate Module")
	NumberOfMaxBuildRates = inputs["NumberOfMaxBuildRates"]
    Max_MW = inputs["MaxBuildMW"]
    Max_Rate = inputs["MaxBuildRate"]

    @expression(EP, eMaxMWFlag, Max_MW .>= 0)
    @expression(EP, eMaxRateFlag, Max_Rate .>= 0)
	@constraint(EP, cZoneMaxBuildRateMW[maxbuildrate in (first.(Tuple.(findall(x->x==1, eMaxMWFlag))))], EP[:eMaxBuildRateTotal][maxbuildrate] <= Max_MW[maxbuildrate])
	@constraint(EP, cZoneMaxBuildRate[maxbuildrate in (first.(Tuple.(findall(x->x==1, eMaxRateFlag))))], EP[:eMaxBuildRateTotal][maxbuildrate] <= Max_Rate[maxbuildrate]*EP[:eMaxBuildRateExisting][maxbuildrate])
end
