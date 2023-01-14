@doc raw"""
	write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)

Function for writing the capacities of different storage technologies, including hydro reservoir, flexible storage tech etc.
"""
function write_storage(path::AbstractString, inputs::Dict,setup::Dict, EP::Model)
	dfGen = inputs["dfGen"]
	T = inputs["T"]     # Number of time steps (hours)
	G = inputs["G"]
	STOR_ALL = inputs["STOR_ALL"]
	HYDRO_RES = inputs["HYDRO_RES"]
	FLEX = inputs["FLEX"]
	VRE_STOR = inputs["VRE_STOR"]
	if !isempty(VRE_STOR)
		VS_STOR = inputs["VS_STOR"]
	end
	
	# Storage level (state of charge) of each resource in each time step
	dfStorage = DataFrame(Resource = inputs["RESOURCES"], Zone = dfGen[!,:Zone])
	storagevcapvalue = zeros(G,T)

	if !isempty(inputs["STOR_ALL"])
	    storagevcapvalue[STOR_ALL, :] = value.(EP[:vS][STOR_ALL, :])
	end
	if !isempty(inputs["HYDRO_RES"])
	    storagevcapvalue[HYDRO_RES, :] = value.(EP[:vS_HYDRO][HYDRO_RES, :])
	end
	if !isempty(inputs["FLEX"])
	    storagevcapvalue[FLEX, :] = value.(EP[:vS_FLEX][FLEX, :])
	end
	if !isempty(VRE_STOR) && !isempty(VS_STOR)
	    storagevcapvalue[VS_STOR, :] = value.(EP[:vS_VRE_STOR][VS_STOR, :])
	end
	if setup["ParameterScale"] == 1
	    storagevcapvalue *= ModelScalingFactor
	end

	dfStorage = hcat(dfStorage, DataFrame(storagevcapvalue, :auto))
	auxNew_Names=[Symbol("Resource");Symbol("Zone");[Symbol("t$t") for t in 1:T]]
	rename!(dfStorage,auxNew_Names)
	
	CSV.write(joinpath(path, "storage.csv"), dftranspose(dfStorage, false), writeheader=false)
end
