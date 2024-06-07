function build_dc_opf!(m::Model)

    ### THIS FUNCTION BUILDS THE MODEL OF AN ADMM AGENT
    ##### TIME STEPS
    T = m.ext[:sets][:time_steps]
    
    ##### SETS
    # Buses
    M = m.ext[:sets][:M]
    MSL = m.ext[:sets][:bus_slack]
    #Connections 
    M_connected = m.ext[:sets][:M_connected] 

    # Generators
    G = m.ext[:sets][:G]
    # Branch
    BR = m.ext[:sets][:BR]
    arcs_fr = m.ext[:sets][:arcs_fr]
    arcs_to = m.ext[:sets][:arcs_to]
    arcs = m.ext[:sets][:arcs]
    bus_ij_ji = m.ext[:sets][:bus_ij_ji]
    bus_ij = m.ext[:sets][:bus_ij]
    bus_ji = m.ext[:sets][:bus_ji]

    # Load
    L= m.ext[:sets][:L]

    ##### PARAMETERS
    baseMVA = m.ext[:baseMVA]
    
    # Buses
    ij_ji_ang_max = m.ext[:sets][:bus][:ij_ji_ang_max]
    ij_ji_ang_min = m.ext[:sets][:bus][:ij_ji_ang_min]
    ij_ang_max = m.ext[:sets][:bus][:ij_ang_max]
    ij_ang_min = m.ext[:sets][:bus][:ij_ang_min]
    ji_ang_max = m.ext[:sets][:bus][:ji_ang_max]
    ji_ang_min = m.ext[:sets][:bus][:ji_ang_min]
  
    # Branches
    br_s_max_a = m.ext[:sets][:branch][:s_max_a]
    br_b = m.ext[:sets][:branch][:b]
    br_ang_min = m.ext[:sets][:branch][:ang_min]
    br_ang_max = m.ext[:sets][:branch][:ang_max]

    # Generators
    gen_cost_lin = m.ext[:sets][:gen][:cost_linear]
    gen_p_max = m.ext[:sets][:gen][:p_max]
    gen_p_min = m.ext[:sets][:gen][:p_min]

    ##### TIME SERIES
    # Loads
    load_p = m.ext[:time_series][:load][:p]

    ##### VARIABLES
    m.ext[:variables] = Dict()
    a= Dict()
    # Generators
    gen_p = m.ext[:variables][:gen_p] = @variable(m, [G,T], base_name="gen_p")

    # Buses
    bus_ang = m.ext[:variables][:bus_ang] = @variable(m, [M,T], base_name="bus_ang",lower_bound=-π, upper_bound=π)

    #SLACK VARIABLE TO BE ABLE TO CORPORATE INEQUALITY COUPLING CONSTRAINTS --> is turned to equality constraint with slack
    S_lower = m.ext[:variables][:slack1] = @variable(m, [arcs_fr,T], base_name="slack1",lower_bound=0)

    #Decision variables put in vector a 
    # a[1] = generation decision variables
    # a[2] = voltage angle decision variables
    a[1]= gen_p
    a[2]= bus_ang
    

    ##### OBJECTIVE FUNCTION
    m.ext[:objective] = @objective(m, Min,
            sum(gen_cost_lin[g][t]*gen_p[g,t] for g in G) 
    )

    ##### CONSTRAINTS
    m.ext[:constraints] = Dict()
    # Generator - Maximum and minimum active power limits
    m.ext[:constraints][:gen_p_max_ub] = @constraint(m, [g=G, t=T],
        gen_p_min[g] <= gen_p[g,t])
    m.ext[:constraints][:gen_p_max_lb] = @constraint(m, [g=G, t=T],
        gen_p[g,t] <= gen_p_max[g])
             
    # Slack bus
    m.ext[:constraints][:ang_sl] = @constraint(m, [msl = MSL, t=T],
        bus_ang[msl,t] == 0)


    return m, a , S_lower
end