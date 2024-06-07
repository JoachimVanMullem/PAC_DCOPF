function init_model_bus!(m::Model, m_central::Dict,bus_id::String,time_steps::Int)

    ### THIS FUNCTION INITIALIZES THE MODEL OF A PAC ATOM

    ################# FIRST THE FULL TOPOLOGY IS LOADED FOR CONVENIENCE #############


    ##### SETS
    # Buses
    M_central = m_central[:sets][:bus] 
    MSL_central  = m_central[:sets][:bus_slack]
    # Generators
    G_central  = m_central[:sets][:gen]

    # Branch
    BR_central  = m_central[:sets][:branch]
    arcs_fr_central  = m_central[:sets][:arcs_fr]
    arcs_to_central = m_central[:sets][:arcs_to]
    arcs_central  = m_central[:sets][:arcs]
    bus_arcs_central  = m_central[:sets][:bus_arcs]
    bus_ij_ji_central  = m_central[:sets][:bus_ij_ji]
    bus_ij_central = m_central[:sets][:bus_ij] 
    bus_ji_central = m_central[:sets][:bus_ji]

    # Load
    D_central  = m_central[:sets][:load]

    ##### PARAMETERS
    baseMVA_central  = m_central[:parameters][:baseMVA]
    
    # Buses
    va_min_central = m_central[:parameters][:bus][:va_min] 
    va_max_central = m_central[:parameters][:bus][:va_max] 
    ij_ji_ang_max_central  = m_central[:parameters][:bus][:ij_ji_ang_max]
    ij_ji_ang_min_central  = m_central[:parameters][:bus][:ij_ji_ang_min]
    
    # Branches
    br_s_max_a_central  = m_central[:parameters][:branch][:s_max_a]
    br_b_central  = m_central[:parameters][:branch][:b]
    br_ang_min_central  = m_central[:parameters][:branch][:ang_min]
    br_ang_max_central  = m_central[:parameters][:branch][:ang_max]

    # Generators
    gen_bus_central  = m_central[:parameters][:gen][:bus]
    #println(gen_bus_central,"genbus")
    gen_cost_lin_central  = m_central[:parameters][:gen][:cost_linear]
    gen_p_max_central  = m_central[:parameters][:gen][:p_max]
    gen_p_min_central  = m_central[:parameters][:gen][:p_min]
    gen_name_central= m_central[:parameters][:gen][:name]

    # Loads
    load_bus_central  = m_central[:parameters][:load][:bus]
    
    ##### TIME SERIES
    # Loads
    load_p_central  = m_central[:time_series][:load][:p]

    ##### MODEL IS BUILD FROM THE PARTS OF THE TOPOLOGY THAT BELONG TO THE CURRENT AGENT FROM HERE 

    ################################### MODEL FOR THIS BUS #####################################

    m.ext[:sets] = Dict()
    m.ext[:sets][:time_steps] = collect(1:time_steps) # set of time steps

    #Businformation
    m.ext[:sets][:bus] = Dict()
    m.ext[:sets][:branch] = Dict()
    m.ext[:sets][:gen] = Dict()
    m.ext[:time_series] = Dict()
    m.ext[:time_series][:load] = Dict()

    m.ext[:sets][:M] = Vector{String}()
    m.ext[:sets][:M_SL] = Vector{String}()
    m.ext[:sets][:G] = Vector{String}()
    m.ext[:sets][:L] = Vector{String}()
    m.ext[:sets][:BR] = Vector{String}()
    m.ext[:sets][:M_connected] = Vector{String}()

    m.ext[:baseMVA]= baseMVA_central

    #SETS 
    #Current bus, should be number
    M = m.ext[:sets][:M] = [bus_id]
    #Check if is slack bus
    M_SL = m.ext[:sets][:bus_slack]=[id for id in MSL_central if id == bus_id]
    #This bus properties
    m.ext[:sets][:bus][:va_min] = Dict(p for p in va_min_central if p.first in M)
    m.ext[:sets][:bus][:va_max] = Dict(p for p in va_max_central if p.first in M)

    #List of connected nodes needed bro, known by their bus_id 
    M_connected = m.ext[:sets][:M_connected] = [t[3] for p in bus_arcs_central if p.first == bus_id for t in p.second]

    #BRANCHES
    #Gives a list of branches that are connected to this bus
    BR = m.ext[:sets][:BR] = [t[1] for p in bus_arcs_central if p.first == bus_id for t in p.second]

    arcs_FR = m.ext[:sets][:arcs_FR] = [(br,i,j) for (br,i,j) in arcs_fr_central if br in BR]
    #Reorder arcs_fr so that that i always corresponds to the bus_id en j to the connected bus
    arcs_fr= m.ext[:sets][:arcs_fr]= []
    for (br,i,j) in arcs_FR
        if i == bus_id
            #println(parse(Int,i),"integerrrr")
            push!(m.ext[:sets][:arcs_fr], (br,i,j))    
        else
            push!(m.ext[:sets][:arcs_fr], (br,j,i)) 
        end
    end
    #println(arcs_fr,"ARCSFR")
    arcs_TO = m.ext[:sets][:arcs_TO] = [(br,i,j) for (br,i,j) in arcs_to_central if br in BR]
    #Reorder arcs_to so that that i always corresponds to the bus_id en j to the connected bus
    arcs_to= m.ext[:sets][:arcs_to]= []  
    for (br,i,j) in arcs_TO
        if j == bus_id
            push!(m.ext[:sets][:arcs_to], (br,i,j))    
        else
            push!(m.ext[:sets][:arcs_to], (br,j,i)) 
        end
    end

    arcs = m.ext[:sets][:arcs] = [arcs_fr;arcs_to]

    # Create bus pairs
    buspair = m.ext[:sets][:buspair] = [pair for pair in bus_ij_ji_central if bus_id in pair]
    
    m.ext[:sets][:bus_ij] = []
    m.ext[:sets][:bus_ji] = []
    contain_bus_ij = []
    for a in m.ext[:sets][:arcs_fr]
        if !((a[2],a[3]) in contain_bus_ij)
            push!(m.ext[:sets][:bus_ij], (a[2],a[3]))
            push!(m.ext[:sets][:bus_ji], (a[3],a[2]))     
            push!(contain_bus_ij, (a[2],a[3]))
        end
    end 

    bus_ij_ji = m.ext[:sets][:bus_ij_ji] = [m.ext[:sets][:bus_ij];m.ext[:sets][:bus_ji]]
    

    #Branch properties
    m.ext[:sets][:branch][:s_max_a] = Dict(p for p in br_s_max_a_central if p.first in BR)
    b= m.ext[:sets][:branch][:b]= Dict(p for p in br_b_central if p.first in BR)
    angmin= m.ext[:sets][:branch][:ang_min] = Dict(p for p in br_ang_min_central  if p.first in BR) 
    angmax= m.ext[:sets][:branch][:ang_max] = Dict(p for p in br_ang_max_central  if p.first in BR)

    m.ext[:sets][:bus][:ij_ang_max] = Dict()
    m.ext[:sets][:bus][:ij_ang_min] = Dict()
    m.ext[:sets][:bus][:ji_ang_max] = Dict()
    m.ext[:sets][:bus][:ji_ang_min] = Dict()
    contain_bus_ij = []
    for a in m.ext[:sets][:arcs_fr]
        if !((a[2],a[3]) in contain_bus_ij)
            if a[2] == bus_id
                m.ext[:sets][:bus][:ij_ang_max][(a[2],a[3])] = angmax[a[1]]
                m.ext[:sets][:bus][:ij_ang_min][(a[2],a[3])] = angmin[a[1]]
                m.ext[:sets][:bus][:ji_ang_max][(a[3],a[2])] = angmax[a[1]]
                m.ext[:sets][:bus][:ji_ang_min][(a[3],a[2])] = angmin[a[1]]
            end

            push!(contain_bus_ij, (a[2],a[3]))
        end
    end

    m.ext[:sets][:bus][:ij_ji_ang_max] = merge!(m.ext[:sets][:bus][:ij_ang_max],m.ext[:sets][:bus][:ji_ang_max])
    m.ext[:sets][:bus][:ij_ji_ang_min] = merge!(m.ext[:sets][:bus][:ij_ang_min],m.ext[:sets][:bus][:ji_ang_min])

 
    #GENERATORS
    #List of generators that are connected to this bus
    G = m.ext[:sets][:G] = [p.first for p in gen_bus_central if p.second == bus_id]
    
    #Properties from gen that are needed
    m.ext[:sets][:gen][:p_max]= Dict(p for p in gen_p_max_central if p.first in G)
    m.ext[:sets][:gen][:p_min]= Dict(p for p in gen_p_min_central if p.first in G) 
    cost_linear = m.ext[:sets][:gen][:cost_linear]= Dict(p for p in gen_cost_lin_central if p.first in G) 
    gen_names = m.ext[:sets][:gen][:name]= Dict(p for p in gen_name_central if p.first in G) 
    #normaal niet meer nodig
    m.ext[:sets][:gen][:bus] = Dict(p  for p in gen_bus_central if p.first in G)

    #LOADS 
    #List of loads connected to this bus --> is only 1 load normally
    L =m.ext[:sets][:L] = [p.first for p in load_bus_central if p.second == bus_id]
    ##### TIME SERIES
    load_p = m.ext[:time_series][:load][:p] = Dict(p  for p in load_p_central if p.first in L)

    return G, cost_linear, arcs_fr, arcs_to, load_p , M_connected, gen_names, b

end