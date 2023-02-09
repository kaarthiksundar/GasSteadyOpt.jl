function get_data(data_folder::AbstractString, 
    nomination_case::AbstractString;
    case_name::AbstractString="", 
    case_types::Vector{Symbol}=Symbol[],
    slack_pressure::Float64 = NaN,
    kwargs...)::Dict{String,Any}
    return _parse_data(data_folder, nomination_case; 
        slack_pressure=slack_pressure,
        case_name=case_name, 
        case_types=case_types
    )
    return initialize_optimizer(data; kwargs...)
end

function write_csv(file, header, rows)
    open(file, "w") do io
        writedlm(io, [permutedims(header); reduce(hcat, rows)'], ',')
    end
end