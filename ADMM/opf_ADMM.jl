using Pkg
Pkg.activate(@__DIR__)
Pkg.instantiate()
using JuMP
using PowerModels
using Gurobi
using DataFrames
using XLSX
using Plots
const PM = PowerModels
using YAML
using DataStructures
using Statistics

## NUMBER OF BUSES SPECIFIED HERE
number= 3
# Setup file+
case_file_name = "$(number)_bus.m"
case_file = joinpath(dirname(@__DIR__), "pg", case_file_name)
case_data = PM.parse_matpower(case_file)
data = YAML.load_file( joinpath(dirname(@__DIR__), "pg", "elec_data.yaml"))

load_time_series_file_name = "$(number)_bus.xlsx"
load_time_series_file =  joinpath(dirname(@__DIR__), "pg",load_time_series_file_name)


# General settings
t = 1
time_steps = collect(1:t)


# Run DC power flow formulation
include("init_model_ADMM.jl")
include("build_dc_opf_ADMM.jl")
include("../initialize_full_model.jl")


# Decomposition (Decomposition in number of nodes --> each atom becomes a node )
num_nodes = number
num_gens = number

baseMVA= 100

#MULTIAGENT APPROACH
N = 1:num_nodes
N_gen= 1:num_gens

#INITIALIZE THE FULL TOPOLOGY
m_central = Dict()
init_topology!(m_central, case_data,t,load_time_series_file,data)


## DEFINE SETS FOR RESULTS
#MODEL FOR EACH ADMM AGENT
m_dc_opf = Dict()
a= Dict()
S_lower = Dict()
a_results = Dict()
G= Dict()
cost_linear= Dict()
arcs_fr= Dict()
arcs_to = Dict()
b= Dict()
pb_max = Dict()
imbalance = Dict()
branchflow = Dict()
M_connected = Dict()
BR= Dict()
imbalance_lowerlimit = Dict()
load =Dict()


#DUAL VARIABLES
λ = Dict()
μ_lower = Dict()


# CONVERGENCE PARAMETERS ADMM (penalization terms)

if number == 3
    ρ_gen = 8.0
    ρ_S_branch = 20.15873679831797
    ρ_θ = 8.0
    ρ_branch = 5.039684199579493
elseif number == 5 || number == 8
    ρ_gen = 0.41669277614165234
    ρ_S_branch = 6.428974260471208
    ρ_θ = 0.5125
    ρ_branch = 0.3875
else
    error("Invalid number. Only 3, 5, or 8 are allowed.")
end


#Number of iterations
time= 200
#Initialization

for i in N
    λ[i] = 0
    μ_lower[string(i)] = Dict()
    imbalance_lowerlimit[string(i)] = Dict()
    a_results[i]= Dict()
    a_results[i][1] = CircularBuffer{Vector{Float64}}(time+1)
    a_results[i][2] = CircularBuffer{Vector{Float64}}(time+1)
    a_results[i][3] = CircularBuffer{Vector{Float64}}(time+1)
end


#Elke node wordt atoom
θ_bar= Dict()
g_bar= Dict()
br_upper_bar = Dict()
θ_upper_bar = Dict()
S_lower_bar = Dict()

function init_model_ADMM(model,N) 
    #Surpress Gurobi print-outs
    GUROBI_ENV = Gurobi.Env()
    GRBsetparam(GUROBI_ENV, "OutputFlag", "0")

    for n in N
        # Create a JuMP model for each agent --> each bus in the model
        model[n] = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(GUROBI_ENV)))
        G[n], cost_linear[n], arcs_fr[n],arcs_to[n], load[n], M_connected[n], BR[n], b[n], pb_max[n]= init_model_bus!(model[n], m_central, string(n),t)
        a[n] = build_dc_opf!(model[n])[2]
        S_lower[n] = build_dc_opf!(model[n])[3]

        for (br,i,j) in arcs_fr[n]
            μ_lower[i][j] = 0
            S_lower_bar[i] = Dict()
        end      
    end
end

init_model_ADMM(m_dc_opf,N)


for i in 1:time
    for n in N 
        JuMP.optimize!(m_dc_opf[n])
        println("Objective Value for Agent ", n, ": ", objective_value(m_dc_opf[n]))
    end 

    for n in N
        #Calculate imbalance in each node 
        imbalance[n]= sum(value.(a[n][1][g,t]) for g in G[n]) - load[n][string(n)][t] +sum(b[n][br]* (value.(a[parse(Int, i)][2][i,t])-value.(a[parse(Int, k)][2][k,t]))  for (br,i,k) in arcs_fr[n]) 
        λ[n] = λ[n] - ρ_gen/2 * imbalance[n]

        #inequality constraint of branchlimits --> equality constraint with slack variable
        for (br,i,j) in arcs_fr[n]
            imbalance_lowerlimit[i][j] = b[n][br]* (value.(a[parse(Int, i)][2][i,t])-value.(a[parse(Int, j)][2][j,t]))+ value.(S_lower[n][(br,i,j),t]) - pb_max[n][br]  
            μ_lower[i][j] =  μ_lower[i][j] +  ρ_branch/2 * imbalance_lowerlimit[i][j]
        end 
        #gen_p
        a_results[n][1] = value.(a[n][1])
        #bus_ang
        a_results[n][2] = value.(a[n][2])   
    end

    for n in N
        g_bar[n]= (sum(value.(a[n][1][g,t]) for g in G[n])) - 1/(num_nodes*2) * imbalance[n]
        θ_bar[n]= (sum(b[n][br] *value.(a[n][2][string(n),t]) for (br,i,k) in arcs_fr[n])) - 1/(num_nodes*2) * imbalance[n] 

        for (br,i,j) in arcs_fr[n]
            S_lower_bar[i][j]= value.(S_lower[n][(br,i,j),t]) - imbalance_lowerlimit[i][j]
        end 

        @objective(m_dc_opf[n], Min, sum(cost_linear[n][g][t]*a[n][1][g,t] - λ[n] *a[n][1][g,t] 
            for g in G[n]) 
            - λ[n] * sum(b[n][br]* a[n][2][string(n),t] for (br,i,k) in arcs_fr[n])
            + sum(λ[parse(Int, k)] * b[n][br]* a[n][2][string(n),t] for (br,i,k) in arcs_fr[n])

            + sum(μ_lower[i][j]*( b[n][br]* (a[n][2][i,t]) + S_lower[n][(br,i,j),t]) for (br,i,j) in arcs_fr[n])
            + sum(μ_lower[j][i]* (-b[n][br]* (a[n][2][i,t])) for (br,i,j) in arcs_fr[n])

            + ρ_gen/2 *(sum(a[n][1][g,t] for g in G[n]) - g_bar[n])^2 
            + ρ_θ/2 *(sum(b[n][br]* a[n][2][string(n),t] for (br,i,k) in arcs_fr[n])- θ_bar[n])^2

            + sum(ρ_S_branch/2 *(S_lower[n][(br,i,j),t] - S_lower_bar[i][j])^2 for (br,i,j) in arcs_fr[n])
            )
    end
end 

