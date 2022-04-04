
function _initialize_solution(data::Dict{String,Any})::Dict{String,Any}
    sol = Dict{String,Any}()
    sol["nodal_pressure"] = Dict{Int64,Float64}()
    sol["pipe_flow"] = Dict{Int64,Float64}()
    sol["compressor_flow"] = Dict{Int64,Float64}()
    sol["nodal_potential"] = Dict{Int64,Float64}()
    sol["receipt_injection"] = Dict{Int64,Float64}()
    sol["delivery_withdrawal"] = Dict{Int64,Float64}()
    sol["receipt_cost"] = 0.0 
    sol["delivery_cost"] = 0.0

    return sol
end