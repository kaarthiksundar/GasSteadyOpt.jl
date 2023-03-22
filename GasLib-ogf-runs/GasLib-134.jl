include("../src/NGSteady.jl")

include("helper.jl")


zip_file = "GasLib-data/json/GasLib-134.zip"
nomination_cases_file = "GasLib-data/data/nomination_files/GasLib-134.json"
apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!]
instance = "\nGasLib-134"
cases, num_cases = read_nomination_cases(nomination_cases_file)

failed_cases = Dict("ideal" => [], "non_ideal" => [], "infeasible" => [])

for case in cases 
    @show case
    # ideal run
    new_instance = instance * " (" * case * ")"
    net_ideal = parse_network_data(zip_file, case,
        apply_on_data = apply_on_data, 
        eos = :ideal 
    )
    result_ideal = run_lp_based_algorithm!(net_ideal)
    pretty_table(result_ideal.stats, title = new_instance * " ideal run stats")
    if result_ideal.stats["status"] == "infeasible"
        push!(failed_cases["infeasible"], case)
    elseif result_ideal.stats["status"] != "globally_optimal"
        push!(failed_cases["ideal"], case)
    end 

    # non ideal run 
    net_non_ideal = parse_network_data(zip_file, case,
        apply_on_data = apply_on_data, 
        eos = :simple_cnga
    )
    result_non_ideal = run_lp_based_algorithm!(net_non_ideal)
    pretty_table(result_non_ideal.stats, title = new_instance * " non ideal run stats")
    if result_non_ideal.stats["status"] == "infeasible"
        push!(failed_cases["infeasible"], case)
    elseif result_non_ideal.stats["status"] != "globally_optimal"
        push!(failed_cases["non_ideal"], case)
    end 
end 

num_ideal_failures = failed_cases["ideal"] |> length
num_non_ideal_failures = failed_cases["non_ideal"] |> length
num_infeasibilites = failed_cases["infeasible"] |> length

println("ideal case failures: $(num_ideal_failures)")
println("non ideal case failures: $(num_non_ideal_failures)")
println("infeasibilities: $(num_infeasibilites)")

function run_case(case = "2011-11-03")
    new_instance = instance * " (" * case * ")"
    net_ideal = parse_network_data(zip_file, case,
            apply_on_data = apply_on_data, 
            eos = :ideal 
    )
    result_ideal = run_lp_based_algorithm!(net_ideal)
    pretty_table(result_ideal.stats, title = new_instance * " ideal run stats")
    
        # non ideal run 
    net_non_ideal = parse_network_data(zip_file, case,
        apply_on_data = apply_on_data, 
        eos = :simple_cnga
    )
    result_non_ideal = run_lp_based_algorithm!(net_non_ideal)
    pretty_table(result_non_ideal.stats, title = new_instance * " non ideal run stats")
end 