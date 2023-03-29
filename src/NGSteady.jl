# module NGSteady

using JuMP
using PolyhedralRelaxations
# using DelimitedFiles

include("useful_scripts/apply_functions.jl")

# submodule import
include("./DataProcessing/DataProcessing.jl")
import .DataProcessing: NetworkData, ref, params, nominal_values, is_ideal,
    get_eos_coeffs, get_pressure, get_density, get_potential, get_potential_derivative, 
    is_pressure_node, parse_network_data, invert_positive_potential, TOL

include("./SolutionProcessing/SolutionProcessing.jl")
using .SolutionProcessing: Solution, ControlType

include("optimization/optimization.jl")

using SparseArrays 
using NLsolve
using LineSearches

include("simulation/simulation.jl")

using Ipopt
using SCIP
using HiGHS

# const gurobi_env = Gurobi.Env(output_flag = 0)
ipopt = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "sb"=>"yes")
highs = optimizer_with_attributes(HiGHS.Optimizer, "log_to_console"=>false)
scip = optimizer_with_attributes(SCIP.Optimizer)

using PrettyTables
using DataStructures

include("algorithms/helper.jl")
include("algorithms/adjust_slack_pressure.jl")
include("algorithms/ogf.jl")

# include("useful_scripts/helper.jl")
# include("useful_scripts/resistor_models.jl")



# end # module
