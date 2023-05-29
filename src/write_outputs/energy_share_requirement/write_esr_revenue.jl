@doc raw"""
	write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)

Function for reporting the renewable/clean credit revenue earned by each generator listed in the input file. GenX will print this file only when RPS/CES is modeled and the shadow price can be obtained form the solver. Each row corresponds to a generator, and each column starting from the 6th to the second last is the total revenue earned from each RPS constraint. The revenue is calculated as the total annual generation (if elgible for the corresponding constraint) multiplied by the RPS/CES price. The last column is the total revenue received from all constraint. The unit is \$.
"""
function write_esr_revenue(path::AbstractString, inputs::Dict, setup::Dict, dfPower::DataFrame, dfESR::DataFrame)
	dfGen = inputs["dfGen"]
	dfESRRev = DataFrame(region = dfGen[!,:region], Resource = inputs["RESOURCES"], zone = dfGen[!,:Zone], Cluster = dfGen[!,:cluster], R_ID = dfGen[!,:R_ID])
	G = inputs["G"]
	for i in 1:inputs["nESR"]
		dfESRRev =  hcat(dfESRRev, dfPower[1:G,:AnnualSum] .* dfGen[!,Symbol("ESR_$i")] * dfESR[i,:ESR_Price])
		# dfpower is in MWh already, price is in $/MWh already, no need to scale
		# if setup["ParameterScale"] == 1
		# 	#dfESRRev[!,:x1] = dfESRRev[!,:x1] * (1e+3) # MillionUS$ to US$
		# 	dfESRRev[!,:x1] = dfESRRev[!,:x1] * ModelScalingFactor # MillionUS$ to US$  # Is this right? -Jack 4/29/2021
		# end
		rename!(dfESRRev, Dict(:x1 => Symbol("ESR_$i")))
	end

	# Vre-Storage Module
	if setup["VreStor"] == 1
		dfGen_VRE_STOR = inputs["dfGen_VRE_STOR"]
		dfESRRevVRESTOR = DataFrame(region = dfGen_VRE_STOR[!,:region], Resource = inputs["RESOURCES_VRE_STOR"], zone = dfGen_VRE_STOR[!,:Zone], Cluster = dfGen_VRE_STOR[!,:cluster], R_ID = dfGen_VRE_STOR[!,:R_ID])
		for i in 1:inputs["nESR"]
			dfESRRevVRESTOR =  hcat(dfESRRevVRESTOR, dfPower[G+1:G+inputs["VRE_STOR"],:AnnualSum] .* dfGen_VRE_STOR[!,Symbol("ESR_$i")] * dfESR[i,:ESR_Price])
			rename!(dfESRRevVRESTOR, Dict(:x1 => Symbol("ESR_$i")))
		end
		dfESRRev = vcat(dfESRRev, dfESRRevVRESTOR)
	end

	dfESRRev.AnnualSum = sum(eachcol(dfESRRev[:,6:inputs["nESR"]+5]))
	CSV.write(joinpath(path, "ESR_Revenue.csv"), dfESRRev)
	return dfESRRev
end
