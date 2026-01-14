function separate_inputs_zones(inputs::Dict)
    inputs_all=Dict();
    number_zones = inputs["Z"] # we assume you decompose by solving every subproblem as is
    gen = inputs["RESOURCES"]

    # This is to ensure all of the right zones get indexed into for the list

    for z in 1:number_zones
        inputs_all[z] = deepcopy(inputs)
        inputs_all[z]["Z"]=1;
        inputs_all[z]["O_Z"]=number_zones;
        inputs_all[z]["oz"]=z;
        inputs_all[z]["og"]=inputs["G"];
        # NEED TO CHANGE ACTUAL ZONE in R_ID to be 1
        # Demand
        inputs_all[z]["pD"] = inputs["pD"][:, z];

        # Generators
        inputs_all[z]["NEW_CAP"] = intersect(inputs["NEW_CAP"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["RET_CAP"] = intersect(inputs["RET_CAP"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["NEW_CAP_ENERGY"] = intersect(inputs["NEW_CAP_ENERGY"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["RET_CAP_ENERGY"] = intersect(inputs["RET_CAP_ENERGY"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["NEW_CAP_CHARGE"] = intersect(inputs["NEW_CAP_CHARGE"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["RET_CAP_CHARGE"] = intersect(inputs["RET_CAP_CHARGE"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["HYDRO_RES"] = intersect(inputs["HYDRO_RES"], resources_in_zone_by_rid(gen, z));
        if !isempty(inputs_all[z]["HYDRO_RES"])
            inputs_all[z]["HYDRO_RES_KNOWN_CAP"] = intersect(inputs["HYDRO_RES_KNOWN_CAP"], resources_in_zone_by_rid(gen, z));
        end

        inputs_all[z]["STOR_ALL"] = intersect(inputs["STOR_ALL"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["STOR_SYMMETRIC"] = intersect(inputs["STOR_SYMMETRIC"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["STOR_ASYMMETRIC"] = intersect(inputs["STOR_ASYMMETRIC"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["STOR_HYDRO_LONG_DURATION"] = intersect(inputs["STOR_HYDRO_LONG_DURATION"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["STOR_HYDRO_SHORT_DURATION"] = intersect(inputs["STOR_HYDRO_SHORT_DURATION"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["STOR_LONG_DURATION"] = intersect(inputs["STOR_LONG_DURATION"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["STOR_SHORT_DURATION"] = intersect(inputs["STOR_SHORT_DURATION"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["VRE"] = intersect(inputs["VRE"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["VRE_STOR"] = intersect(inputs["VRE_STOR"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["FLEX"] = intersect(inputs["FLEX"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["MUST_RUN"] = intersect(inputs["MUST_RUN"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["ELECTROLYZER"] = intersect(inputs["ELECTROLYZER"], resources_in_zone_by_rid(gen, z));

        inputs_all[z]["THERM_ALL"] = intersect(inputs["THERM_ALL"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["THERM_NO_COMMIT"] = intersect(inputs["THERM_NO_COMMIT"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["THERM_COMMIT"] = intersect(inputs["THERM_COMMIT"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["COMMIT"] = intersect(inputs["COMMIT"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["CCS"] = intersect(inputs["CCS"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["HAS_FUEL"] = intersect(inputs["HAS_FUEL"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["SINGLE_FUEL"] = intersect(inputs["SINGLE_FUEL"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["MULTI_FUELS"] = intersect(inputs["MULTI_FUELS"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["RETROFIT_CAP"] = intersect(inputs["RETROFIT_CAP"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["RETROFIT_OPTIONS"] = intersect(inputs["RETROFIT_OPTIONS"], resources_in_zone_by_rid(gen, z));
        inputs_all[z]["RETROFIT_IDS"] = intersect(inputs["RETROFIT_IDS"], resources_in_zone_by_rid(gen, z));

        # I think this should be comprehensive?
        indices = union(
            inputs_all[z]["HYDRO_RES"], 
            inputs_all[z]["STOR_ALL"], 
            inputs_all[z]["VRE"], 
            inputs_all[z]["VRE_STOR"], 
            inputs_all[z]["FLEX"], 
            inputs_all[z]["MUST_RUN"], 
            inputs_all[z]["ELECTROLYZER"], 
            inputs_all[z]["THERM_ALL"]
        );
        inputs_all[z]["G"] = size(indices)[1]; # length of resources in this
        inputs_all[z]["G_indices"] = indices;
        inputs_all[z]["RESOURCE_NAMES"] = inputs["RESOURCE_NAMES"][indices]; # resource names
        inputs_all[z]["R_ZONES"] = inputs["R_ZONES"][indices]; # zones in ordered list
        #inputs_all[z]["RESOURCES"] = inputs["RESOURCES"][indices]; # resources abstract type with all of data
        for r in inputs_all[z]["RESOURCES"]
            r.Zone = r.zone
            r.zone = 1
        end
        inputs_all[z]["RESOURCE_ZONES"] = inputs["RESOURCE_ZONES"][indices]; # resources' name + zone
        inputs_all[z]["SubPeriod"] = z;
        #inputs_all[z]["C_Start"] = inputs["C_Start"][indices,:];

        # If piecewise heatrates, would also consider PWFU_Num_Segments and THERM_COMMIT_PWFU
        # If VRE-STORAGE, would need to split resources
        # If multiple fuels, would consider MULTI_FUELS
        # If allam cycle lox, would need to redo
        # If retrofits, would need to rethink

        # Fuel - could separate access to fuels but I don't find it absolutely essential now because they're linked to generator

        # Network - simplify number of lines and pNet_Map
        pNet_Map = inputs["pNet_Map"];
        lines_idx = findall(!=(0), pNet_Map[:, z]);
        inputs_all[z]["L_indices"] = lines_idx
        #inputs_all[z]["pNet_Map"] = pNet_Map[lines_idx, :];
        inputs_all[z]["L"] = size(inputs_all[z]["pNet_Map"])[1];
        inputs_all[z]["EXPANSION_LINES"]  = intersect(inputs["EXPANSION_LINES"], inputs_all[z]["L"]);
        
        # Generators_variability
        #inputs_all[z]["pP_Max"] = inputs["pP_Max"][indices,:];

        # Policies (?) - for later
    
    end

    println("Done separating subzones")

    return inputs_all
end


function separate_inputs_subperiods(inputs::Dict)

    inputs_all=Dict();
    number_periods = inputs["REP_PERIOD"];
    hours_per_subperiod = inputs["hours_per_subperiod"];
    
    ####### entries_to_be_changed = ["omega","REP_PERIOD",","INTERIOR_SUBPERIODS","START_SUBPERIODS","pP_Max","T","fuel_costs","Weights","pD","C_Start"];

    for w in 1:number_periods
        inputs_all[w] = deepcopy(inputs)
        # This computes time indices for that subperiod- 1:168 for example
        Tw = (w-1)*hours_per_subperiod+1:w*hours_per_subperiod;
        # Weights of time period assigned to each hour --> all should sum to total number of hours
        inputs_all[w]["omega"] = inputs["omega"][Tw];
        # One representative period is represented by subperiods
        inputs_all[w]["REP_PERIOD"]=1;

        # Starting hour/interior hour
        STARTS = 1:hours_per_subperiod:hours_per_subperiod;
        INTERIORS = setdiff(1:hours_per_subperiod,STARTS);   
        inputs_all[w]["INTERIOR_SUBPERIODS"] = INTERIORS;
        inputs_all[w]["START_SUBPERIODS"] = STARTS;

        # Gather generators variability
        inputs_all[w]["pP_Max"] = inputs["pP_Max"][:,Tw];
        inputs_all[w]["T"] = hours_per_subperiod;

        # Fuel costs
        for ks in keys(inputs["fuel_costs"])
            inputs_all[w]["fuel_costs"][ks] = inputs["fuel_costs"][ks][Tw];
        end

        # Period weight (to scale objective function)
        inputs_all[w]["Weights"] = [inputs["Weights"][w]];

        # Demand
        inputs_all[w]["pD"] = inputs["pD"][Tw,:];

        # Start-up costs
        inputs_all[w]["C_Start"] = inputs["C_Start"][:,Tw]; 

        # Sub-period number
        inputs_all[w]["SubPeriod"] = w;

        # Original mapping
		if haskey(inputs,"Period_Map")
			inputs_all[w]["SubPeriod_Index"] = inputs["Period_Map"].Rep_Period[findfirst(inputs["Period_Map"].Rep_Period_Index.==w)];
		end

    end

    return inputs_all

end


function generate_benders_inputs(setup::Dict,inputs::Dict,inputs_decomp::Dict)

    planning_problem, planning_variables = init_planning_problem(setup,inputs);

    subproblems_dist,planning_variables_sub = init_dist_subproblems(setup,inputs_decomp,planning_variables);

    benders_inputs = Dict();
	benders_inputs["planning_problem"] = planning_problem;
	benders_inputs["planning_variables"] = planning_variables;

    benders_inputs["subproblems"] = subproblems_dist;
	benders_inputs["planning_variables_sub"] = planning_variables_sub;

    return benders_inputs


end

function check_negative_capacities(EP::Model)

	neg_cap_bool = false;
	tol = -1e-8;
	if any(value.(EP[:eTotalCap]).< tol) 
			neg_cap_bool = true;
	elseif haskey(EP,:eTotalCapEnergy)
		if any(value.(EP[:eTotalCapEnergy]).< tol)
			neg_cap_bool = true;
		end
	elseif haskey(EP,:eTotalCapCharge)
		if any(value.(EP[:eTotalCapCharge]).< tol)
			neg_cap_bool = true;
		end
	elseif haskey(EP,:eAvail_Trans_Cap)
		if any(value.(EP[:eAvail_Trans_Cap]).< tol)
			neg_cap_bool = true;
		end
	end
	return neg_cap_bool
	
end