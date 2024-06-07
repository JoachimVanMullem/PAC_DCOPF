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
using Ipopt

# SPECIFY BUS NUMBER HERE

number= 3

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
time =500
# Run DC power flow formulation
include("init_model_PAC_variant.jl")
include("build_dc_opf_PAC_variant_NL.jl")
include("../initialize_full_model.jl")

#INITIALIZE THE FULL TOPOLOGY
m_central = Dict()
init_topology!(m_central, case_data,t,load_time_series_file,data)


baseMVA= 100
#MULTIAGENT APPROACH
N = 1:num_nodes
N_gen= 1:num_gens
m_dc_opf = Dict()
#atoom
a= Dict()
a_results = Dict()

ν= Dict()
ν_hat= Dict()

G= Dict()
M_connected = Dict()
cost_linear= Dict()
arcs_fr= Dict()
arcs_to = Dict()
load= Dict()
gen_names= Dict()


#Convergence parameters for PAC-variant

if number == 3
    ρ = 125.0
    γ = 62.71211382783801
    ρ_θ = 8.05439328410769e-5
elseif number == 5 || number == 8
    ρ = 7874.506561842957
    γ = 3.8236224566586503
    ρ_θ = 1.378838201620405e-5
else
    error("Invalid number. Only 3, 5, or 8 are allowed.")
end




for i in N
    ν[string(i)]= Dict()
    ν_hat[string(i)] = Dict()
    a_results[i]= Dict()
    a_results[i][1] = CircularBuffer{Vector{Float64}}(time+1)
    a_results[i][2] = CircularBuffer{Vector{Float64}}(time+1)
    a_results[i][3] = CircularBuffer{Vector{Float64}}(time+1)
end


#Elke node wordt atoom
b= Dict()

function init_atom(model,N) 
    #Surpress Gurobi print-outs

    for n in N
        # Create a JuMP model for each agent --> each bus in the model
        model[n] = Model(Ipopt.Optimizer)
        G[n], cost_linear[n], arcs_fr[n],arcs_to[n], load[n], M_connected[n], gen_names[n], b[n]= init_model_bus!(model[n], m_central, string(n),t)
        a[n] = build_dc_opf!(model[n])[2]

        for m in M_connected[n]
            ν[string(n)][m]= 0
            ν_hat[string(n)][m] = 0
        end 
        
    end
end

init_atom(m_dc_opf,N)

 
#To save the results of the duals of the different atoms (2 duals per atom)
MSE= CircularBuffer{Float64}(time+1)

for i in 1:time
    for n in N 
        JuMP.optimize!(m_dc_opf[n])
        println("Objective Value for Agent ", n, ": ", objective_value(m_dc_opf[n]))
    end 
 
    for n in N
        for m in M_connected[n]
            mint = parse(Int, m)
            ν[string(n)][m]= ν[string(n)][m] + ρ* γ * (value.(a[n][3][m,t])- value.(a[mint][2][m,t]))
            ν_hat[string(n)][m]= ν[string(n)][m] + ρ* γ * (value.(a[n][3][m,t])- value.(a[mint][2][m,t]))
        end 
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
        + 1/(2ρ_θ) * sum((a[n][2].- a_results[n][2]).^2) 
        + 1/(2ρ_θ)* sum((a[n][3].- a_results[n][3]).^2)
        + sum(ν_hat[string(n)][m]* a[n][3][m,t] for m in M_connected[n]) 
        - sum(ν_hat[m][string(n)]*a[n][2][string(n),t] for m in M_connected[n]))
    end 


end
