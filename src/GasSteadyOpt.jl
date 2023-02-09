# module GasSteadyOpt

import JSON
import ZipFile
using JuMP
using PolyhedralRelaxations

include("io/json.jl")
include("io/data_utils.jl")

include("unit_conversion/unit_convertor_utils.jl")
include("unit_conversion/to_si.jl")
include("unit_conversion/to_english.jl")
include("unit_conversion/to_pu.jl")
include("unit_conversion/unit_convertors.jl")

include("core/eos.jl")
include("core/types.jl")
include("core/bounds.jl")
include("core/ref.jl")
include("core/sol.jl")

# include("form/variables.jl")
# include("form/constraints.jl")
# include("form/nlp.jl")

include("core/initialize_sopt.jl")

include("useful_scripts/helper.jl")
include("useful_scripts/resistor_models.jl")
include("useful_scripts/loss_resistor_models.jl")



# end # module
