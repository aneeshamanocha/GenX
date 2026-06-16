using JLD2
using DataFrames, CSV

data = load((@__DIR__)*"/inputs_dict_RTS_v2.jld2")

# List all high-level categories
println(keys(data["inputs"]))
myinputs = data["inputs"]



#println(pD)
#println(myinputs["R_ZONES"])




#inputs["REP_PERIOD"] = 52
#inputs["hours_per_subperiod"] = 168

#omega
#Weights