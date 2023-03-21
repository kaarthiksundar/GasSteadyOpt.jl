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

using HiGHS 
using CPLEX 
using Juniper 
using Ipopt
nl_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "sb"=>"yes")
mip_solver = optimizer_with_attributes(CPLEX.Optimizer, "CPX_PARAM_SCRIND"=>0)
minlp_solver = optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>nl_solver, "mip_solver"=>mip_solver)

include("algorithms/helper.jl")
include("algorithms/compute_slack_pressure.jl")

# include("core/types.jl")
# include("core/bounds.jl")
# include("core/ref.jl")
# include("core/sol.jl")

# include("form/variables.jl")
# include("form/constraints.jl")
# include("form/objective.jl")
# include("form/nlp.jl")
# include("form/lp.jl")

# include("core/initialize_sopt.jl")

# include("useful_scripts/helper.jl")
# include("useful_scripts/resistor_models.jl")



# end # module
