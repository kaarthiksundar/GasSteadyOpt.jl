include("../../src/DataProcessing/DataProcessing.jl")
import .DataProcessing
import JSON
using DelimitedFiles

scip_error_nominations_4197 = ["nomination_mild_0108", "nomination_cold_0131", 
    "nomination_cold_2515", "nomination_cold_2803", "nomination_cool_0605"]

struct Result 
    data::Vector 
    header::Vector 
    count::Int 
end 

function read_nomination_cases(file::AbstractString)::NamedTuple
    data = DataProcessing._parse_json(file)
    num_cases = (data |> last)["files"]
    cases = map(x -> split(x["name"], ".")[1], (data |> first)["contents"])
    return (cases = cases, num_cases = num_cases)
end

function save_results(case::AbstractString)
    nomination_case_path = "GasLib-data/data/nomination_files/"
    nomination_case_name = case * ".json"

    cases, _ = read_nomination_cases(nomination_case_path * nomination_case_name)

    result_path = "GasLib-ogf-runs/paper-runs/output/" * case * "/"

    result = collect_results(result_path, cases)
    errored_cases = result.errored_cases 
    scip_error_cases = [] 
    (case == "GasLib-4197") && (scip_error_cases = scip_error_nominations_4197)
    filter!(x -> !(x in scip_error_cases), errored_cases)
    @assert result.errored_case_count == length(scip_error_cases) + length(errored_cases)

    success = "csv/" * case * "-success.csv"
    minlp_infeasible = "csv/" * case * "-minlp-infeasible.csv"
    relaxation_infeasible = "csv/" * case * "-relaxation-infeasible.csv"
    minlp_time_out = "csv/" * case * "-time-limit.csv" 
    scip_error = "csv/" * case * "-scip-error.csv"
    other_error = "csv/" * case * "-other-error.csv"

    open(success, "w") do io
        writedlm(io, [permutedims(result.success.header); mapreduce(permutedims, vcat, result.success.data)], ',')
    end

    if !isempty(errored_cases)
        open(other_error, "w") do io 
            writedlm(io, errored_cases, ',')
        end 
        # create_additional_runs(case, errored_cases)
    end 

    if !isempty(scip_error_cases)
        open(scip_error, "w") do io 
            writedlm(io, scip_error_cases, ',')
        end  
    end 

    if !isempty(result.minlp_infeasible.data)
        open(minlp_infeasible, "w") do io 
            writedlm(io, [permutedims(result.minlp_infeasible.header); mapreduce(permutedims, vcat, result.minlp_infeasible.data)], ',')
        end 
    end 

    if !isempty(result.relaxation_infeasible.data)
        open(relaxation_infeasible, "w") do io 
            writedlm(io, [permutedims(result.relaxation_infeasible.header); mapreduce(permutedims, vcat, result.relaxation_infeasible.data)], ',')
        end 
    end 

    if !isempty(result.minlp_time_out.data)
        open(minlp_time_out, "w") do io 
            writedlm(io, [permutedims(result.minlp_time_out.header); mapreduce(permutedims, vcat, result.minlp_time_out.data)], ',')
        end 
    end 

    return result
end 

function create_additional_runs(case::AbstractString, cases::Vector) 
    @assert case == "GasLib-4197"
    to_write = map(x -> "julia --project=. GasLib-ogf-runs/paper-runs/main.jl -z GasLib-data/json/GasLib-4197.zip -n " * x, cases)
    open("GasLib-4197-remaining-runs", "w") do io 
        writedlm(io, to_write, ',')
    end 
end 

function collect_results(path::AbstractString, cases::Vector)
    total_cases = cases |> length 
    successful_runs = 0
    minlp_infeasible_runs = 0 
    relaxation_infeasible_runs = 0 
    minlp_time_limit_runs = 0
    errored_runs = 0
    errored_cases = []
    successful_rows = [] 
    minlp_infeasible_rows = []  
    minlp_time_limit_rows = []
    relaxation_infeasible_rows = [] 
    successful_header = ["case", "minlp_time", "misoc_time", "lp_time", "lp_gap", "misoc_gap"]
    minlp_infeasible_header = ["case", "minlp_solve_time"] 
    relaxation_infeasible_header = ["case", "minlp_time", "misoc_time", "lp_time"]
    minlp_time_limit_header = ["case", "minlp_time", "misoc_time", "lp_time"]
    for case in cases 
        file = path * case * ".json"
        (isfile(file) == false) && (push!(errored_cases, case); errored_runs += 1; continue)
        data = JSON.parsefile(file)
        
        if (data["minlp_status"] == "INFEASIBLE")
            if (data["lp_status"] == "INFEASIBLE")
                relaxation_infeasible_runs += 1 
                row = [case, isnothing(data["minlp_solve_time"]) ? NaN : round(data["minlp_solve_time"]; digits=2), 
                    round(data["misoc_solve_time"]; digits=2), 
                    round(data["lp_solve_time"]; digits=2)]
                push!(relaxation_infeasible_rows, row)
            else 
                minlp_infeasible_runs += 1 
                row = [case, round(data["minlp_solve_time"]; digits=2)]
                push!(minlp_infeasible_rows, row)
            end 
            continue
        end 

        if (data["lp_status"] == "INFEASIBLE")
            relaxation_infeasible_runs += 1 
            row = [case, data["minlp_solve_time"], 
                    round(data["misoc_solve_time"]; digits=2), 
                    round(data["lp_solve_time"]; digits=2)]
            push!(relaxation_infeasible_rows, row) 
            relaxation_infeasible_runs += 1 
            continue 
        end 
        
        if (data["minlp_status"] == "TIME_LIMIT") 
            row = [case, round(data["minlp_solve_time"]; digits=2), 
                    round(data["misoc_solve_time"]; digits=2), 
                    round(data["lp_solve_time"]; digits=2)]
            minlp_time_limit_runs += 1
            push!(minlp_time_limit_rows, row)
            continue 
        end 

        successful_runs += 1
        row = [case, round(data["minlp_solve_time"]; digits=2), 
                    round(data["misoc_solve_time"]; digits=2), 
                    round(data["lp_solve_time"]; digits=2)]
        minlp_obj = data["minlp_objective"]
        lp_obj = data["lp_objective"]
        misoc_obj = data["misoc_objective"]
        lp_gap = abs(minlp_obj - lp_obj)/minlp_obj * 100.0
        lp_gap = (abs(lp_gap) < 1e-4) ? 0.0 : lp_gap
        if isnothing(misoc_obj)
            append!(row, lp_gap, NaN)
        else 
            misoc_gap = abs(minlp_obj - misoc_obj)/minlp_obj * 100.0
            misoc_gap = (abs(misoc_gap) < 1e-4) ? 0.0 : misoc_gap
            append!(row, lp_gap, misoc_gap)
        end 
        push!(successful_rows, row)
    end 

    successful = Result(successful_rows, successful_header, successful_runs)
    minlp_infeasible = Result(minlp_infeasible_rows, minlp_infeasible_header, minlp_infeasible_runs)
    relaxation_infeasible = Result(relaxation_infeasible_rows, relaxation_infeasible_header, relaxation_infeasible_runs)
    minlp_time_limit = Result(minlp_time_limit_rows, minlp_time_limit_header, minlp_time_limit_runs)

    return (success = successful, 
        minlp_infeasible = minlp_infeasible, 
        relaxation_infeasible = relaxation_infeasible, 
        minlp_time_out = minlp_time_limit, 
        errored_cases = errored_cases,
        errored_case_count = errored_runs, 
        total_cases = total_cases)
end 

save_results("GasLib-134")
save_results("GasLib-582")
save_results("GasLib-4197")