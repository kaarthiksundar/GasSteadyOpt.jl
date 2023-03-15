# module GasSteadyOpt

using JuMP
using PolyhedralRelaxations
# using DelimitedFiles

include("useful_scripts/apply_functions.jl")

# submodule import
include("./DataProcessing/DataProcessing.jl")
import .DataProcessing: NetworkData, ref, params, nominal_values, 
    get_eos_coeffs, get_pressure, get_density, get_potential, is_pressure_node,
    parse_network_data, invert_positive_potential

include("./SolutionProcessing/SolutionProcessing.jl")
using .SolutionProcessing: Solution

include("optimization/optimization.jl")


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
