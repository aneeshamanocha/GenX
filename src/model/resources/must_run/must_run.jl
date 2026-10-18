@doc raw"""
	must_run!(EP::Model, inputs::Dict, setup::Dict)

This function defines the constraints for operation of `must-run' or non-dispatchable resources, such as rooftop solar systems that do not receive dispatch signals, run-of-river hydroelectric facilities without the ability to spill water, or cogeneration systems that must produce a fixed quantity of heat in each time step. This resource type can also be used to model baseloaded or self-committed thermal generators that do not respond to economic dispatch.

For must-run resources ($y\in \mathcal{MR}$) output in each time period $t$ must exactly equal the available capacity factor times the installed capacity, not allowing for curtailment. These resources are also not eligible for contributing to frequency regulation or operating reserve requirements.

```math
\begin{aligned}
\Theta_{y,z,t} = \rho^{max}_{y,z,t}\times \Delta^{total}_{y,z}
\hspace{4 cm}  \forall y \in \mathcal{MR}, z \in \mathcal{Z},t \in \mathcal{T}
\end{aligned}
```
When the required output is a constant, it is imposed as a fixed variable bound
instead of a singleton equality. Capacity-dependent output retains the equality.
"""
function must_run!(EP::Model, inputs::Dict, setup::Dict)
    println("Must-Run Resources Module")

    T = inputs["T"]     # Number of time steps (hours)
    Z = inputs["Z"]     # Number of zones
    G = inputs["G"] # Number of generators

    MUST_RUN = inputs["MUST_RUN"]
    CapacityReserveMargin = setup["CapacityReserveMargin"]

    ### Expressions ###

    ## Power Balance Expressions ##
    # Look up must-run resources per zone from the precomputed incidence (Part 1.0) with O(1)
    # membership, instead of rebuilding resources_in_zone_by_rid(gen, z) per zone.
    MUST_RUN_set = BitSet(MUST_RUN)
    MUST_RUN_BY_ZONE = [filter(y -> y in MUST_RUN_set, rids)
                        for rids in inputs["RESOURCES_BY_ZONE"]]
    @expression(EP, ePowerBalanceNdisp[t = 1:T, z = 1:Z],
        sum(EP[:vP][y, t] for y in MUST_RUN_BY_ZONE[z]))
    add_similar_to_expression!(EP[:ePowerBalance], ePowerBalanceNdisp)

    # Capacity Reserves Margin policy
    if CapacityReserveMargin > 0
        nCRMZones = inputs["NCapacityReserveMargin"]
        capresfactor = inputs["DERATING_FACTOR"]
        @expression(EP,
            eCapResMarBalanceMustRun[res = 1:nCRMZones, t = 1:T],
            sum(capresfactor[y, res] * EP[:eTotalCap][y] *
                inputs["pP_Max"][y, t] for y in MUST_RUN))
        add_similar_to_expression!(EP[:eCapResMarBalance], eCapResMarBalanceMustRun)
    end

    ### Constratints ###

    output_rows = ConstraintRef[]
    for y in MUST_RUN
        capacity = EP[:eTotalCap][y]
        # Only constant capacity can prescribe positive output before solving.
        # Investment, retirement and multistage capacity terms keep their rows.
        capacity_value = if capacity isa Number
            capacity
        elseif capacity isa AffExpr && all(iszero(coef) for (coef, _) in linear_terms(capacity))
            constant(capacity)
        else
            nothing
        end
        for t in 1:T
            availability = inputs["pP_Max"][y, t]
            output = if iszero(availability)
                0.0
            elseif capacity_value !== nothing
                availability * capacity_value
            else
                nothing
            end
            power = EP[:vP][y, t]
            # force=true removes native bounds. Retain the original equality if
            # its required value conflicts with any bound, preserving infeasibility.
            if output !== nothing && isfinite(output) &&
               (!has_lower_bound(power) || output >= lower_bound(power)) &&
               (!has_upper_bound(power) || output <= upper_bound(power)) &&
               (!is_fixed(power) || output == fix_value(power))
                fix(power, output; force = true)
            else
                push!(output_rows, @constraint(EP, power == availability * capacity))
            end
        end
    end
    EP[:cMustRunOutput] = output_rows
    ##CO2 Polcy Module Must Run Generation by zone
    @expression(EP, eGenerationByMustRun[z = 1:Z, t = 1:T], # the unit is GW
        sum(EP[:vP][y, t] for y in MUST_RUN_BY_ZONE[z]))
    add_similar_to_expression!(EP[:eGenerationByZone], eGenerationByMustRun)
end
