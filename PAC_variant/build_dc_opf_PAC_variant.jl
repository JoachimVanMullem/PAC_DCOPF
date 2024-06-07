function build_dc_opf!(m::Model)

    ### THIS FUNCTION BUILDS THE MODEL OF A PAC AGENT
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

    #Copy of the voltage angle for each connected bus
    bus_ang_copy = m.ext[:variables][:bus_ang_copy] = @variable(m, [M_connected,T], base_name="bus_ang_copy",lower_bound=-π, upper_bound=π)

    a[1]= gen_p
    a[2]= bus_ang
    a[3]= bus_ang_copy

    ##### OBJECTIVE FUNCTION
    m.ext[:objective] = @objective(m, Min,
            sum(sum(gen_cost_lin[g][t]*gen_p[g,t] for g in G) for t in T)
    )

    ##### CONSTRAINTS
    m.ext[:constraints] = Dict()
    # Generator - Maximum and minimum active power limits
    m.ext[:constraints][:gen_p_max_ub] = @constraint(m, [g=G, t=T],
        gen_p_min[g] <= gen_p[g,t])
    m.ext[:constraints][:gen_p_max_lb] = @constraint(m, [g=G, t=T],
        gen_p[g,t] <= gen_p_max[g])
             

    # Active branch power flow limits
    m.ext[:constraints][:p_b_max_lb] = @constraint(m, [(br,i,j) = arcs_fr, t=T],
        -br_s_max_a[br] <= -br_b[br]*(bus_ang[i,t]-bus_ang_copy[j,t]))

    m.ext[:constraints][:p_b_max_ub] = @constraint(m, [(br,i,j) = arcs_fr, t=T],
        -br_b[br]*(bus_ang[i,t]-bus_ang_copy[j,t]) <= br_s_max_a[br])

    m.ext[:constraints][:p_b_max_lb_to] = @constraint(m, [(br,j,i) = arcs_to, t=T],
        -br_s_max_a[br] <= -br_b[br]*(bus_ang_copy[j,t]-bus_ang[i,t]))

    m.ext[:constraints][:p_b_max_ub_to] = @constraint(m, [(br,j,i) = arcs_to, t=T],
        -br_b[br]*(bus_ang_copy[j,t]-bus_ang[i,t]) <= br_s_max_a[br])                    
    

    #angledifference limits
    m.ext[:constraints][:ang_ij_ub] = @constraint(m, [(i,j) = bus_ij, t=T],
        bus_ang[i,t] - bus_ang_copy[j,t] <= ij_ang_max[(i,j)])

    m.ext[:constraints][:ang_ij_lb] = @constraint(m, [(i,j) = bus_ij, t=T],
        ij_ang_min[(i,j)] <= bus_ang[i,t] - bus_ang_copy[j,t])

    m.ext[:constraints][:ang_ji_ub] = @constraint(m, [(j,i) = bus_ji, t=T],
        bus_ang_copy[j,t] - bus_ang[i,t] <= ji_ang_max[(j,i)])

    m.ext[:constraints][:ang_ji_lb] = @constraint(m, [(j,i) = bus_ji, t=T],
        ji_ang_min[(j,i)] <= bus_ang_copy[j,t] - bus_ang[i,t])

    # Slack bus
    m.ext[:constraints][:ang_sl] = @constraint(m, [msl = MSL, t=T],
        bus_ang[msl,t] == 0)

    #nodal power balance
    m.ext[:constraints][:nodal_balance] = @constraint(m, [t=T],
        sum(gen_p[gen_id,t] for gen_id in G) 
        - sum(load_p[load_id][t] for load_id in L)
        - sum(-br_b[br]*(bus_ang[i,t]-bus_ang_copy[j,t]) for (br,i,j) in arcs_fr) 
        == 0) 

    return m, a
end