include("types.jl")

include("initialize_solution.jl")

include("form/variables.jl")
include("form/constraints.jl")
include("form/objective.jl")
include("form/nlp.jl")
include("form/lp.jl")
include("form/misocp.jl")

include("initialize_optimizer.jl")
include("populate_optimization_solution.jl")
