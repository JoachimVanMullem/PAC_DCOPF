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
using Metaheuristics

number= 3
# Setup file+

case_file_name = "$(number)_bus.m"
case_file = joinpath(dirname(@__DIR__), "pg", case_file_name)
case_data = PM.parse_matpower(case_file)
data = YAML.load_file( joinpath(dirname(@__DIR__), "pg", "elec_data.yaml"))

load_time_series_file_name = "$(number)_bus.xlsx"
load_time_series_file =  joinpath(dirname(@__DIR__), "pg",load_time_series_file_name)


# Decomposition (Decomposition in number of nodes --> each atom becomes a node )
num_nodes = number
num_gens = number

# General settings
t = 1
time_steps = collect(1:t)

# Number of iterations 
time= 300
# Run DC power flow formulation
include("init_model_PAC.jl")
include("build_dc_opf_PAC.jl")
include("../initialize_full_model.jl")


baseMVA= 100
#MULTIAGENT APPROACH
N = 1:num_nodes
N_gen= 1:num_gens

#INITIALIZE THE FULL TOPOLOGY
m_central = Dict()
init_topology!(m_central, case_data,t,load_time_series_file,data)


m_dc_opf = Dict()
#atoom
a= Dict()
a_results = Dict()

ν= Dict()
ν_hat= Dict()
μ = Dict()
μ_hat = Dict()

G= Dict()
M_connected = Dict()
cost_linear= Dict()
arcs_fr= Dict()
arcs_to = Dict()
load= Dict()
gen_names = Dict()

#3bus parameters
ρ =0.12327935896270334
ρ_θ = 6.228809564034494e-5
γ= 13.724595449512707
γ_hat=9.727385545876925e7


#Initialization

for i in N
    ν[string(i)]= Dict()
    ν_hat[string(i)] = Dict()
    a_results[i]= Dict()
    a_results[i][1] = CircularBuffer{Vector{Float64}}(time+1)
    a_results[i][2] = CircularBuffer{Vector{Float64}}(time+1)
    a_results[i][3] = CircularBuffer{Vector{Float64}}(time+1)
    μ[i]= 0.0
    μ_hat[i]= 0.0
end


#Elke node wordt atoom
b= Dict()

function init_atom(model,N) 
    #Surpress Gurobi print-outs
    GUROBI_ENV = Gurobi.Env()
    GRBsetparam(GUROBI_ENV, "OutputFlag", "0")

    for n in N
        # Create a JuMP model for each agent --> each bus in the model
        model[n] = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(GUROBI_ENV)))
        G[n], cost_linear[n], arcs_fr[n],arcs_to[n], load[n], M_connected[n],gen_names[n], b[n]= init_model_bus!(model[n], m_central, string(n),t)
        a[n] = build_dc_opf!(model[n])[2]
        for m in M_connected[n]
            ν[string(n)][m]= 0
            ν_hat[string(n)][m] = 0
        end 
        
    end
end

init_atom(m_dc_opf,N)


for i in 1:time
    for n in N 
        JuMP.optimize!(m_dc_opf[n])
        println("Objective Value for Agent ", n, ": ", objective_value(m_dc_opf[n]))
    end 

    for n in N
        μ[n] = μ[n] - ρ* γ* (sum(value.(a[n][1][gen_id,t]) for gen_id in G[n])
        - sum(-b[n][br]*(value.(a[n][2][i,t])- value.(a[n][3][j,t])) for (br,i,j) in arcs_fr[n])
        - load[n][string(n)][t])

        μ_hat[n] = μ[n] - ρ* γ *(sum(value.(a[n][1][gen_id,t]) for gen_id in G[n])
        - sum(-b[n][br]*(value.(a[n][2][i,t])- value.(a[n][3][j,t])) for (br,i,j) in arcs_fr[n])
        - load[n][string(n)][t])

        for m in M_connected[n]
            mint = parse(Int, m)
            ν[string(n)][m]= ν[string(n)][m] + ρ_θ* γ_hat* (value.(a[n][3][m,t]) - value.(a[mint][2][m,t]))
            ν_hat[string(n)][m]= ν[string(n)][m] + ρ_θ* γ_hat* (value.(a[n][3][m,t]) - value.(a[mint][2][m,t]))
        end 

        #Save result of the optimization
        #gen_p
        a_results[n][1] = value.(a[n][1])
        #bus_ang
        a_results[n][2] = value.(a[n][2])
        #bus_ang_copy, can be more copies
        a_results[n][3] = value.(a[n][3])     
    end

    
    for n in N
        @objective(m_dc_opf[n], Min, sum( cost_linear[n][g][t]*a[n][1][g,t] for g in G[n]) 
        + 1/(2ρ) * sum((a[n][1].- a_results[n][1]).^2)
        + 1/(2ρ_θ) *sum((a[n][2].- a_results[n][2]).^2) 
        + 1/(2ρ_θ) * sum((a[n][3].- a_results[n][3]).^2)

        - μ_hat[n] * (sum((a[n][1][gen_id,t]) for gen_id in G[n])
        - sum(-b[n][br]*(a[n][2][i,t] - a[n][3][j,t]) for (br,i,j) in arcs_fr[n]) 
        - load[n][string(n)][t])

        + sum(ν_hat[string(n)][m]* a[n][3][m,t] for m in M_connected[n]) 
        - sum(ν_hat[m][string(n)]*a[n][2][string(n),t] for m in M_connected[n]))
    end

end

