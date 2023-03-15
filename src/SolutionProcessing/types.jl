initialize_control()::Dict{Symbol,Any} = Dict{Symbol,Any}(
    :node => Dict{Any,Any}(), 
    :compressor => Dict{Any,Any}(), 
    :control_valve => Dict{Any,Any}(), 
    :valve => Dict{Any,Any}(),
    :decision_group => Dict{Any,Any}(),
    :is_empty => true
)

initialize_state()::Dict{Symbol,Any} = Dict{Symbol,Any}(
    :node => Dict{Any,Any}(), 
    :pipe => Dict{Any,Any}(), 
    :resistor => Dict{Any,Any}(), 
    :loss_resistor => Dict{Any,Any}(),
    :short_pipe => Dict{Any,Any}(),
    :compressor => Dict{Any,Any}(), 
    :control_valve => Dict{Any,Any}(), 
    :valve => Dict{Any,Any}(),
    :is_empty => true
)

@enum ControlType begin
    c_ratio_control = 0
    c_additive_control = 1 
    flow_control = 2
    pressure_control = 3
    unknown_control = 100
end

struct Solution 
    state::Dict{Symbol,Any}
    control::Dict{Symbol,Any}
    state_guess::Dict{Symbol,Any}
end 

Solution() = Solution(initialize_state(), initialize_control(), initialize_state())