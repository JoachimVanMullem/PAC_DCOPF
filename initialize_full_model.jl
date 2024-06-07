function init_topology!(m::Dict, grid_data::Dict,time_steps::Int,load_time_series_file::String, extra_data::Dict)

    ##### SETS
    m[:sets] = Dict()
    ##### TIME STEPS
    m[:sets][:time_steps] = collect(1:time_steps) # set of time steps

    # Buses
    M = m[:sets][:bus] = [bus_id for (bus_id,bus) in grid_data["bus"]]
    MSL = m[:sets][:bus_slack] = [bus_id for (bus_id,bus) in grid_data["bus"] if bus["bus_type"] == 3] # set of slack buses
    # Generators
    G = m[:sets][:gen] = [gen_id for (gen_id,gen) in grid_data["gen"]]
    # Branch
    BR = m[:sets][:branch] = [br_id for (br_id,br) in grid_data["branch"]] # branches
    # Topology
    arcs_fr = m[:sets][:arcs_fr] = [(br_id,string(br["f_bus"]),string(br["t_bus"])) for (br_id,br) in grid_data["branch"]] # arc branch from to
    arcs_to = m[:sets][:arcs_to] = [(br_id,string(br["t_bus"]),string(br["f_bus"])) for (br_id,br) in grid_data["branch"]] # arc branch to from
    arcs = m[:sets][:arcs] = [arcs_fr;arcs_to]
    bus_arcs = Dict((b_id, Tuple{String,String,String}[]) for b_id in m[:sets][:bus])
    for (l,i,j) in arcs
        push!(bus_arcs[i], (l,i,j))
    end
    m[:sets][:bus_arcs] = bus_arcs
    
    # Create bus pairs
    m[:sets][:bus_ij] = []
    m[:sets][:bus_ji] = []
    contain_bus_ij = []
    for a in m[:sets][:arcs_fr]
        if !((a[2],a[3]) in contain_bus_ij)
            push!(m[:sets][:bus_ij], (a[2],a[3]))
            push!(m[:sets][:bus_ji], (a[3],a[2]))     
            push!(contain_bus_ij, (a[2],a[3]))
        end
    end
    m[:sets][:bus_ij_ji] = [m[:sets][:bus_ij];m[:sets][:bus_ji]]

    # Load
    D = m[:sets][:load] = [load_id for (load_id,load) in grid_data["load"]] # set of loads

    ##### PARAMETERS
    m[:parameters] = Dict()
    baseMVA = m[:parameters][:baseMVA] = grid_data["baseMVA"]

   
    # Buses
    m[:parameters][:bus] = Dict()
    m[:parameters][:bus][:va_min] = Dict(bus_id => -pi for (bus_id,bus) in grid_data["bus"])
    m[:parameters][:bus][:va_max] = Dict(bus_id => pi for (bus_id,bus) in grid_data["bus"])


    # Branches
    m[:parameters][:branch] = Dict()
    m[:parameters][:branch][:s_max_a] = Dict(br_id => br["rate_a"] for (br_id,br) in grid_data["branch"])
    m[:parameters][:branch][:b] = Dict(br_id => imag(1/(br["br_r"] + br["br_x"]im)) for (br_id,br) in grid_data["branch"])
    m[:parameters][:branch][:ang_min] = Dict(br_id => br["angmin"] for (br_id,br) in grid_data["branch"])
    m[:parameters][:branch][:ang_max] = Dict(br_id => br["angmax"] for (br_id,br) in grid_data["branch"])

    m[:parameters][:bus][:ij_ang_max] = Dict()
    m[:parameters][:bus][:ij_ang_min] = Dict()
    m[:parameters][:bus][:ji_ang_max] = Dict()
    m[:parameters][:bus][:ji_ang_min] = Dict()
    contain_bus_ij = []
    for a in m[:sets][:arcs_fr]
        if !((a[2],a[3]) in contain_bus_ij)
            m[:parameters][:bus][:ij_ang_max][(a[2],a[3])] = grid_data["branch"][a[1]]["angmax"]
            m[:parameters][:bus][:ij_ang_min][(a[2],a[3])] = grid_data["branch"][a[1]]["angmin"]
            m[:parameters][:bus][:ji_ang_max][(a[3],a[2])] = grid_data["branch"][a[1]]["angmax"]
            m[:parameters][:bus][:ji_ang_min][(a[3],a[2])] = grid_data["branch"][a[1]]["angmin"]
            push!(contain_bus_ij, (a[2],a[3]))
        end
    end
    m[:parameters][:bus][:ij_ji_ang_max] = merge!(m[:parameters][:bus][:ij_ang_max],m[:parameters][:bus][:ji_ang_max])
    m[:parameters][:bus][:ij_ji_ang_min] = merge!(m[:parameters][:bus][:ij_ang_min],m[:parameters][:bus][:ji_ang_min])

    # Generators
    m[:parameters][:gen] = Dict()
    m[:parameters][:gen][:bus] =  Dict(gen_id => string(gen["gen_bus"]) for (gen_id,gen) in grid_data["gen"])

    m[:parameters][:gen][:p_max] = Dict(gen_id => gen["pmax"] for (gen_id,gen) in grid_data["gen"])
    m[:parameters][:gen][:p_min] = Dict(gen_id => gen["pmin"] for (gen_id,gen) in grid_data["gen"])

    # Loads
    m[:parameters][:load] = Dict()
    m[:parameters][:load][:bus] = Dict(load_id => string(load["load_bus"]) for (load_id,load) in grid_data["load"])
    m[:parameters][:load][:p_d] = Dict(load_id => load["pd"] for (load_id,load) in grid_data["load"])
    m[:parameters][:load][:cost_curt] = Dict(load_id => 100000 for (load_id,load) in grid_data["load"])
    bus_load = m[:parameters][:bus_load]= Dict(m_ => [] for m_ in m[:sets][:bus])
    for (m_,load_) in bus_load
        for (load_id,load_bus) in m[:parameters][:load][:bus]
            if load_bus==m_
                push!(load_,load_id)
            end
        end
        if isempty(load_)
            delete!(bus_load,m_)
        end
    end

    ##### TIME SERIES
    m[:time_series] = Dict()
    # Loads
    load_pd_time_series_df = DataFrame(XLSX.readtable(load_time_series_file,"pd"))
    load_pd_time_series_dict_init = Dict(pairs(eachcol(load_pd_time_series_df)))
    m[:time_series][:load] = Dict()
    m[:time_series][:load][:p] = Dict(string(df_id) => df for (df_id,df) in load_pd_time_series_dict_init)

    #Parameters of generators
    gen_name = m[:parameters][:gen][:name] = Dict(gen_id => gen["col_1"] for (gen_id,gen) in grid_data["generator_name"])

    #price in Pound/MWh_elec
    m[:parameters][:gen][:cost_linear] = Dict()
    m[:parameters][:gen][:ramprate] = Dict()
    m[:time_series][:gas_price_MWh_elec]= Dict()

    for (gen_id,name) in gen_name
        m[:parameters][:gen][:cost_linear][gen_id] = Dict()

        d = extra_data[string(name)]
        for t in 1:time_steps
            m[:parameters][:gen][:cost_linear][gen_id][t] = d["price"]
        end
        
    end
    return m, gen_name
end