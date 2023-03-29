include("../../src/DataProcessing/DataProcessing.jl")
import .DataProcessing

function read_nomination_cases(file::AbstractString)::NamedTuple
    data = DataProcessing._parse_json(file)
    num_cases = (data |> last)["files"]
    cases = map(x -> split(x["name"], ".")[1], (data |> first)["contents"])
    return (cases = cases, num_cases = num_cases)
end 

function create_runs(case::AbstractString)
    
    zip_file_path = "GasLib-data/json/" 
    nomination_case_path = "GasLib-data/data/nomination_files/" 

    zip_name = (case == "134") ? "GasLib-134.zip" : (case == "582") ? "GasLib-582.zip" : "GasLib-4197.zip"
    nomination_case_name =  split(zip_name, ".")[1] * ".json"
    run_filename =  split(zip_name, ".")[1] * "-runs"

    cases, _ = read_nomination_cases(nomination_case_path * nomination_case_name)
    to_write = ""
    for case in cases 
        zip_str = " -z " * zip_file_path * zip_name
        case_str = " -n " * case
        line = "julia --project=. GasLib-ogf-runs/paper-runs/main.jl" * zip_str * case_str * "\n"
        to_write *= line
    end 

    open(run_filename, "w") do f
        write(f, to_write)
    end
    return 
end 

create_runs("134")
create_runs("582")
create_runs("4197")