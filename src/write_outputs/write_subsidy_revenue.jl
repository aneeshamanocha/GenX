@doc raw"""
	write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for reporting subsidy revenue earned if a generator specified `Min_Cap` is provided in the input file, or if a generator is subject to a Minimum Capacity Requirement constraint. The unit is \$.
"""
function write_subsidy_revenue(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	G = inputs["G"]

	dfSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
	MIN_CAP = dfGen[(dfGen[!, :Min_Cap_MW].>0), :R_ID]
	dfSubRevenue.SubsidyRevenue[MIN_CAP] .= (value.(EP[:eTotalCap])[MIN_CAP]) .* (dual.(EP[:cMinCap][MIN_CAP])).data

	# Subsidy Revenue for VRE-storage
	if setup["VreStor"]==1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		VRE_STOR = inputs["VRE_STOR"]
		dfSubRevenueVRESTOR = DataFrame(Region = dfGen_VRE_STOR[!,:region], Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], Cluster = dfGen_VRE_STOR[!,:cluster], R_ID = dfGen_VRE_STOR[!,:R_ID], SubsidyRevenue = zeros(VRE_STOR))
		MIN_CAP_VRE_STOR = dfGen_VRE_STOR[(dfGen_VRE_STOR[!, :Min_Cap_VRE_MW].>0), :R_ID]
		dfSubRevenueVRESTOR.SubsidyRevenue[MIN_CAP_VRE_STOR] .= (value.(EP[:eTotalCap_VRE])[MIN_CAP_VRE_STOR]) .* (dual.(EP[:cMinCap_VRE][MIN_CAP_VRE_STOR])).data
		dfSubRevenue = vcat(dfSubRevenue, dfSubRevenueVRESTOR)
	end

	### calculating tech specific subsidy revenue
	dfRegSubRevenue = DataFrame(Region = dfGen[!, :region], Resource = inputs["RESOURCES"], Zone = dfGen[!, :Zone], Cluster = dfGen[!, :cluster], R_ID=dfGen[!, :R_ID], SubsidyRevenue = zeros(G))
	if (setup["MinCapReq"] >= 1)
		if !isempty(VRE_STOR)
			dfVRE_STOR = inputs["dfVRE_STOR"]
		end
		for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
			MIN_CAP_GEN = intersect(dfGen[(dfGen[!, Symbol("MinCapTag_$mincap")].==1), :R_ID], dfVRE_STOR[(dfVRE_STOR[!, Symbol("MinCapTag_$mincap")].==1), :R_ID])
			dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] .= dfRegSubRevenue.SubsidyRevenue[MIN_CAP_GEN] + (value.(EP[:eTotalCap][MIN_CAP_GEN])) * (dual.(EP[:cZoneMinCapReq][mincap]))
		end
	end

	if setup["VreStor"]==1
		dfRegSubRevenueVRESTOR = DataFrame(Region = dfGen_VRE_STOR[!,:region], Resource = inputs["RESOURCES_VRE_STOR"], Zone = dfGen_VRE_STOR[!,:Zone], Cluster = dfGen_VRE_STOR[!,:cluster], R_ID = dfGen_VRE_STOR[!,:R_ID], SubsidyRevenue = zeros(VRE_STOR))
		if (setup["MinCapReq"] >= 1)
			for mincap in 1:inputs["NumberOfMinCapReqs"] # This key only exists if MinCapReq >= 1, so we can't get it at the top outside of this condition.
				MIN_CAP_GEN_VRE_STOR = dfGen_VRE_STOR[(dfGen_VRE_STOR[!, Symbol("MinCapTag_$mincap")].==1), :R_ID]
				dfRegSubRevenueVRESTOR.SubsidyRevenue[MIN_CAP_GEN_VRE_STOR] .= dfRegSubRevenueVRESTOR.SubsidyRevenue[MIN_CAP_GEN_VRE_STOR] + (value.(EP[:eTotalCap_VRE][MIN_CAP_GEN_VRE_STOR])) * (dual.(EP[:cZoneMinCapReq][mincap]))
			end
		end
		
		dfRegSubRevenue = vcat(dfRegSubRevenue, dfRegSubRevenueVRESTOR)
	end

	if setup["ParameterScale"] == 1
		dfSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
		dfRegSubRevenue.SubsidyRevenue *= ModelScalingFactor^2 #convert from Million US$ to US$
	end

	CSV.write(joinpath(path, "SubsidyRevenue.csv"), dfSubRevenue)
	CSV.write(joinpath(path, "RegSubsidyRevenue.csv"), dfRegSubRevenue)
	return dfSubRevenue, dfRegSubRevenue
end
