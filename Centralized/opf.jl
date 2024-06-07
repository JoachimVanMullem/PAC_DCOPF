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
using Statistics
using Plots
using DataStructures

####CENTRALIZED OPTIMIZATION OF DC-OPF 

# Setup file

#NUMBER OF BUSES SPECIFIED HERE
number= 3
case_file_name = "$(number)_bus.m"
case_file = joinpath(@__DIR__,"pg",case_file_name)
case_data = PM.parse_matpower(case_file)

#LOADING PRICES OF THE GENERATORS
data = YAML.load_file(joinpath(@__DIR__,"pg", "elec_data.yaml"))

#LOAD THE DEMAND DATA
load_time_series_file_name = "$(number)_bus.xlsx"
load_time_series_file = joinpath(@__DIR__,"pg",load_time_series_file_name)

# General settings
t =1
time_steps = collect(1:t)

# Run AC power flow formulation using PowerModels
PM_dc_opf_results = PM.solve_dc_opf(case_file, Gurobi.Optimizer)

# Validation
println([PM_dc_opf_results["objective"]])
PM.print_summary(PM_dc_opf_results["solution"])

# Run DC power flow formulation
include("init_model_opf_central.jl")
include("build_dc_opf_central.jl")
m_dc_opf = Model(Gurobi.Optimizer)
init_model!(m_dc_opf,case_data,t,load_time_series_file,data)
println(m_dc_opf.ext[:parameters][:gen][:cost_linear])
build_dc_opf!(m_dc_opf)
optimize!(m_dc_opf)





