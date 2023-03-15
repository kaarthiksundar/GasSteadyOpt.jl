struct SteadySimulator 
    net::NetworkData 
    sim_ref::Dict{Symbol,Any}
    solution::Solution 
end 

ref(ss::SteadySimulator) = ss.sim_ref
ref(ss::SteadySimulator, key::Symbol) = ss.sim_ref[key] 
ref(ss::SteadySimulator, key::Symbol, id::Int64) = ss.sim_ref[key][id]
ref(ss::SteadySimulator, key::Symbol, id::Int64, field) = ss.sim_ref[key][id][field]
params(ss::SteadySimulator) = params(ss.net)
params(ss::SteadySimulator, key::Symbol) = params(ss.net, key)

nominal_values(ss::SteadySimulator) = nominal_values(ss.net)
nominal_values(ss::SteadySimulator, key::Symbol) = nominal_values(ss.net, key)

get_eos_coeffs(ss::SteadySimulator) = get_eos_coeffs(ss.net)
get_pressure(ss::SteadySimulator, density) = get_pressure(ss.net, density)
get_density(ss::SteadySimulator, pressure) = get_density(ss.net, pressure)

get_potential(ss::SteadySimulator, pressure) = get_potential(ss.net, pressure)

is_pressure_node(ss::SteadySimulator, node_id, is_ideal) = is_pressure_node(ss.net, node_id, is_ideal)

initial_pipe_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:pipe][id]["flow"] 
initial_resistor_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:resistor][id]["flow"] 
initial_loss_resistor_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:loss_resistor][id]["flow"] 
initial_short_pipe_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:short_pipe][id]["flow"] 
initial_compressor_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:compressor][id]["flow"]
initial_control_valve_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:control_valve][id]["flow"]
initial_valve_flow(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:valve][id]["flow"]
initial_nodal_pressure(ss::SteadySimulator, id::Int64) = ss.solution.state_guess[:node][id]["pressure"]



function control(ss::SteadySimulator,
    key::Symbol, id::Int64)::Tuple{CONTROL_TYPE,Float64}
    (key == :node) && (return get_nodal_control(ss, id))
    (key == :compressor) && (return get_compressor_control(ss, id))
    (key == :control_valve) && (return get_control_valve_control(ss, id))
    @error "control available only for nodes, compressors, and control_valves"
    return CONTROL_TYPE::unknown_control, 0.0
end


function get_nodal_control(ss::SteadySimulator,
    id::Int64)::Tuple{CONTROL_TYPE,Float64}
    if !haskey(ss.boundary_conditions[:node], id)
        return flow_control, 0.0
    end
    control_type = ss.boundary_conditions[:node][id]["control_type"]
    val = ss.boundary_conditions[:node][id]["val"]
    return control_type, val
end

function get_compressor_control(ss::SteadySimulator,
    id::Int64)::Tuple{CONTROL_TYPE,Float64}
    control_type = ss.boundary_conditions[:compressor][id]["control_type"]
    val = ss.boundary_conditions[:compressor][id]["val"]
    return CONTROL_TYPE(control_type), val
end

function get_control_valve_control(ss::SteadySimulator,
    id::Int64)::Tuple{CONTROL_TYPE,Float64}
    control_type = ss.boundary_conditions[:control_valve][id]["control_type"]
    val = ss.boundary_conditions[:control_valve][id]["val"]
    return CONTROL_TYPE(control_type), val
end

@enum CONTROL_TYPE begin
    c_ratio_control = 0
    discharge_pressure_control = 1
    flow_control = 2
    pressure_control = 3
    unknown_control = 100
end

@enum SOLVER_STATUS begin 
    unique_physical_solution = 0 
    nl_solve_failure = 1 
    unique_unphysical_solution = 2 
    unphysical_solution = 3
end

struct SolverReturn 
    status::SOLVER_STATUS
    iterations::Int 
    residual_norm::Float64 
    time::Float64 
    solution::Vector{Float64}
    negative_flow_in_compressors::Vector{Int64}
    negative_potentials_in_nodes::Vector{Int64}
    pressure_domain_not_satisfied_in_nodes::Vector{Int64}
end 