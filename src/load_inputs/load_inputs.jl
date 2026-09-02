using JLD2

@doc raw"""
	load_inputs(setup::Dict,path::AbstractString)

Loads various data inputs from multiple input .csv files in path directory and stores variables in a Dict (dictionary) object for use in model() function

inputs:
setup - dict object containing setup parameters
path - string path to working directory

returns: Dict (dictionary) object containing all data inputs
"""
function load_inputs(setup::Dict, path::AbstractString)

    ## Declare Dict (dictionary) object used to store parameters
    inputs = Dict()
    # IF THIS INPUT FILE ALREADY EXISTS, JUST READ IT IN
    inputs_file = joinpath(path, "inputs_dict_RTS_v2.jld2")
    if isfile(inputs_file)
        data = JLD2.load(joinpath(path, "inputs_dict_RTS_v2.jld2"))
        inputs = data["inputs"]
        inputs["flag_JLD2"] = 1
        println("Successfully read in inputs for NREL RTS system")
        # Fix network issues from David
        # sparse(): the serialized pNet_Map is a dense Matrix; modern GenX
        # (transmission!) calls findnz() on it, which requires a sparse matrix.
        inputs["pNet_Map"] = sparse(inputs["pNet_Map"][1:120, :])
        inputs["pTrans_Max"] = inputs["pTrans_Max"][1:120]
        inputs["pC_Line_Reinforcement"] = inputs["pC_Line_Reinforcement"][121:240]
        inputs["EXPANSION_LINES"] = inputs["EXPANSION_LINES"] .- 120
        inputs["L"] = 120
        #inputs["pMax_D_Curtail"] = [100.0]
        #inputs["pC_D_Curtail"] = [10000000.0]
        # Some read issues with allam cycle (?)

        # RTS JLD2 stores ramp as a per-MINUTE fraction (and inconsistently); GenX treats
        # Ramp_*_Percentage as per-TIMESTEP (hour). Reassign per technology to the standard
        # per-hour values (match example_systems Thermal.csv).
        for r in inputs["RESOURCES"]
            haskey(r, :ramp_up_percentage) || continue          # skips VRE/storage/MustRun/etc.
            nm = uppercase(string(get(r, :resource, "")))
            rate = occursin("NUCLEAR", nm) ? 0.25 :
                occursin("STEAM",   nm) ? 0.57 :
                occursin("CC",      nm) ? 0.64 :
                occursin("CT",      nm) ? 3.78 :
                occursin("IC",      nm) ? 3.78 : get(r, :ramp_up_percentage, 1.0)
            r.ramp_up_percentage = rate
            r.ramp_dn_percentage = rate
        end

        allam_dict = Dict()
        inputs["allam_dict"] = allam_dict
        ALLAM_CYCLE_LOX = Vector{Any}()  # empty vector
        inputs["ALLAM_CYCLE_LOX"] = ALLAM_CYCLE_LOX

        # RESOURCES_BY_ZONE: zone -> resource-id bins. Not present in the older
        # serialized dict, so rebuild it exactly like load_resources_data! does
        # (resource position = resource id, since ids run 1:G).
        Z = inputs["Z"]
        resources_by_zone = [Int[] for _ in 1:Z]
        for (i, z) in enumerate(inputs["R_ZONES"])
            1 <= z <= Z && push!(resources_by_zone[z], i)
        end
        inputs["RESOURCES_BY_ZONE"] = resources_by_zone

        # ---- Number of 168-hour periods to model (takes the FIRST n_rep weeks) ----
        # Change this to run more/fewer weeks: 5, 6, 7, 11, ...
        n_rep = 5
        hours_per_subperiod = 168
        T = n_rep * hours_per_subperiod   # total modeled hours

        inputs["pP_Max"] = inputs["pP_Max"][:, 1:T]
        inputs["pD"] = inputs["pD"][1:T, :]
        inputs["C_Start"] = inputs["C_Start"][:, 1:T]
        for ks in keys(inputs["fuel_costs"])
            inputs["fuel_costs"][ks] = inputs["fuel_costs"][ks][1:T]
        end

        inputs["T"] = T
        inputs["H"] = hours_per_subperiod
        inputs["hours_per_subperiod"] = hours_per_subperiod
        inputs["REP_PERIOD"] = n_rep
        # each 168-hour week represents itself (literal run, not annualized)
        inputs["Weights"] = fill(Float64(hours_per_subperiod), n_rep)
        inputs["omega"] = ones(Float64, T)
        # subperiod boundaries land at hours 1, 169, 337, ... — recompute both sets
        inputs["START_SUBPERIODS"] = 1:hours_per_subperiod:T
        inputs["INTERIOR_SUBPERIODS"] = setdiff(1:T, inputs["START_SUBPERIODS"])

        # ---- Restore fuel CO2 content ----
        # The serialized jld2 has fuel_CO2 (tCO2/MMBTU) all zeros, which forces zero
        # emissions regardless of thermal generation -- so emissions.csv reads 0 and any
        # CO2 cap is non-binding. Put back standard emission factors (ratio units, no
        # ParameterScale factor). The OTHER_* labels are anonymized in this dataset but
        # are the actual ~9.4 GW thermal fleet -> assigned natural-gas-equivalent
        # (0.05306) so emissions are nonzero and the cap binds. This is a TESTING
        # ASSUMPTION, not the true per-fuel intensity.
        ng = 0.05306
        co2_content = Dict(
            "NATURAL_GAS_4" => ng,
            "COAL_2" => 0.09552,
            "DISTILLATE_FUEL_OIL_6" => 0.07396,
            "NUCLEAR_7" => 0.0, "None" => 0.0,
            "OTHER_1" => ng, "OTHER_3" => ng, "OTHER_5" => ng, "OTHER_8" => ng,
        )
        for (f, v) in co2_content
            haskey(inputs["fuel_CO2"], f) && (inputs["fuel_CO2"][f] = v)
        end

        # ---- CO2 cap policy components (native CO2Cap flag) ----
        # This branch skips load_co2_cap!, so hand-build what co2_cap! reads. A single
        # system-wide mass cap over ALL zones and ALL hours: cCO2Emissions_systemwide then
        # couples every zone AND every representative period -> the both-axis linking row.
        if setup["CO2Cap"] >= 1
            Zc = inputs["Z"]
            inputs["NCO2Cap"] = 1
            inputs["dfCO2CapZones"] = ones(Int, Zc, 1)          # all zones in the one cap
            # Budget = constraint RHS = column-sum of dfMaxCO2, in the model's INTERNAL
            # scaled emission units (ParameterScale=1 => kilotonnes). emissions.csv reports
            # tonnes (internal x scale_factor=1000). Calibrated: uncapped E_csv = 2.366e9 t,
            # so the 0.8x cap = 0.8 * 2.366e9 / 1000 = 1.893e6 ktons.
            co2_budget = 1.893e6                                 # 0.8x uncapped emissions (ktons)
            dfMaxCO2 = zeros(Float64, Zc, 1)
            dfMaxCO2[1, 1] = co2_budget                          # whole budget in one zone; RHS is the sum
            inputs["dfMaxCO2"] = dfMaxCO2
            # Soft cap with penalty slack (for Benders). PriceCap here is stored INTERNAL
            # (already scaled): the CSV flow feeds 9999 and load_co2_cap! divides by
            # ModelScalingFactor(1000) -> 9.999. We bypass load_co2_cap!, so store 9.999
            # directly to match the Benders CSV PriceCap of 9999.
            inputs["dfCO2Cap_slack"] = DataFrame(PriceCap = [9.999])
        end

        validatetimebasis(inputs)
        return inputs
    else
        inputs["flag_JLD2"] = 0
        println("Continue reading without NREL RTS system")
    end
    
    ## Read input files
    println("Reading Input CSV Files")
    ## input paths
    system_path = joinpath(path, setup["SystemFolder"])
    resources_path = joinpath(path, setup["ResourcesFolder"])
    policies_path = joinpath(path, setup["PoliciesFolder"])
    
    # Read input data about power network topology, operating and expansion attributes
    if isfile(joinpath(system_path, "Network.csv"))
        network_var = load_network_data!(setup, system_path, inputs)
    else
        inputs["Z"] = 1
        inputs["L"] = 0
    end

    # Read temporal-resolved load data, and clustering information if relevant
    load_demand_data!(setup, path, inputs)
    # Read fuel cost data, including time-varying fuel costs
    load_fuels_data!(setup, path, inputs)
    # Read in generator/resource related inputs
    load_resources_data!(inputs, setup, path, resources_path)
    # Read in generator/resource availability profiles
    load_generators_variability!(setup, path, inputs)

    validatetimebasis(inputs)

    if setup["CapacityReserveMargin"] == 1
        load_cap_reserve_margin!(setup, policies_path, inputs)
        if inputs["Z"] > 1
            load_cap_reserve_margin_trans!(setup, inputs, network_var)
        end
    end

    # Read in general configuration parameters for operational reserves (resource-specific reserve parameters are read in load_resources_data)
    if setup["OperationalReserves"] == 1
        load_operational_reserves!(setup, system_path, inputs)
    end

    if setup["MinCapReq"] == 1
        load_minimum_capacity_requirement!(policies_path, inputs, setup)
    end

    if setup["MaxCapReq"] == 1
        load_maximum_capacity_requirement!(policies_path, inputs, setup)
    end

    if setup["EnergyShareRequirement"] == 1
        load_energy_share_requirement!(setup, policies_path, inputs)
    end

    if setup["HourlyMatchingRequirement"] == 1
        load_hourly_matching_requirement!(setup, policies_path, inputs)
    end

    if setup["CO2Cap"] >= 1
        load_co2_cap!(setup, policies_path, inputs)
    end

    if !isempty(inputs["VRE_STOR"])
        load_vre_stor_variability!(setup, path, inputs)
    end

    # Read in hydrogen damand data
    if setup["HydrogenMinimumProduction"] == 1
        load_hydrogen_demand!(setup, policies_path, inputs)
    end

    # Read in mapping of modeled periods to representative periods
    if is_period_map_necessary(inputs) && is_period_map_exist(setup, path)
        load_period_map!(setup, path, inputs)
    end

    # Virtual charge discharge cost
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1
    inputs["VirtualChargeDischargeCost"] = setup["VirtualChargeDischargeCost"] /
                                           scale_factor

    println("CSV Files Successfully Read In From $path")

    return inputs
end

function is_period_map_necessary(inputs::Dict)
    multiple_rep_periods = inputs["REP_PERIOD"] > 1
    has_stor_lds = !isempty(inputs["STOR_LONG_DURATION"])
    has_hydro_lds = !isempty(inputs["STOR_HYDRO_LONG_DURATION"])
    has_vre_stor_lds = !isempty(inputs["VRE_STOR"]) && !isempty(inputs["VS_LDS"])
    multiple_rep_periods && (has_stor_lds || has_hydro_lds || has_vre_stor_lds)
end

function is_period_map_exist(setup::Dict, path::AbstractString)
    filename = "Period_map.csv"
    is_in_system_dir = isfile(joinpath(path, setup["SystemFolder"], filename))
    is_in_TDR_dir = isfile(joinpath(path, setup["TimeDomainReductionFolder"], filename))
    is_in_system_dir || is_in_TDR_dir
end

"""
	get_systemfiles_path(setup::Dict, TDR_directory::AbstractString, path::AbstractString)

Determine the directory based on the setup parameters.

This function checks if the TimeDomainReduction setup parameter is equal to 1 and if time domain reduced files exist in the data directory. 
If the condition is met, it returns the path to the TDR_results data directory. Otherwise, it returns the system directory specified in the setup.

Parameters:
- setup: Dict{String, Any} - The GenX settings parameters containing TimeDomainReduction and SystemFolder information.
- TDR_directory: String - The data directory where files are located.
- path: String - Path to the case folder.

Returns:
- String: The directory path based on the setup parameters.
"""
function get_systemfiles_path(setup::Dict,
        TDR_directory::AbstractString,
        path::AbstractString)
    if setup["TimeDomainReduction"] == 1 && time_domain_reduced_files_exist(TDR_directory)
        return TDR_directory
    else
        # If TDR is not used, then use the "system" directory specified in the setup
        return joinpath(path, setup["SystemFolder"])
    end
end

abstract type AbstractLogMsg end
struct ErrorMsg <: AbstractLogMsg
    msg::String
end
struct WarnMsg <: AbstractLogMsg
    msg::String
end
