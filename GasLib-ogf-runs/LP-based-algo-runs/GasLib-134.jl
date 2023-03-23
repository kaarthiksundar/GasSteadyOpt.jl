include("../src/NGSteady.jl")

include("helper.jl")


zip_file = "GasLib-data/json/GasLib-134.zip"
nomination_cases_file = "GasLib-data/data/nomination_files/GasLib-134.json"
apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!]
instance = "\nGasLib-134"
cases, num_cases = read_nomination_cases(nomination_cases_file)

failed_cases = Dict("ideal" => [], "non_ideal" => [])
infeasible_cases = Dict("ideal" => [], "non_ideal" => [])


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
        push!(infeasible_cases["ideal"], case)
    end
    if result_ideal.stats["status"] == "feasible_solution_recovery_failure"
        push!(failed_cases["ideal"], case)
    end 

    # non ideal run 
    net_non_ideal = parse_network_data(zip_file, case,
        apply_on_data = apply_on_data, 
        eos = :simple_cnga
    )
    result_non_ideal = run_lp_based_algorithm!(net_non_ideal)
    if result_non_ideal.stats["status"] == "infeasible"
        push!(infeasible_cases["non_ideal"], case)
    end 
    pretty_table(result_non_ideal.stats, title = new_instance * " non ideal run stats")
    if result_non_ideal.stats["status"] == "feasible_solution_recovery_failure"
        push!(failed_cases["non_ideal"], case)
    end 
end 

num_ideal_failures = failed_cases["ideal"] |> length
num_non_ideal_failures = failed_cases["non_ideal"] |> length
num_ideal_infeasibilites = infeasible_cases["ideal"] |> length
num_non_ideal_infeasibilites = infeasible_cases["non_ideal"] |> length

println("ideal case failures: $(num_ideal_failures)")
println("non ideal case failures: $(num_non_ideal_failures)")
println("ideal infeasibilities: $(num_ideal_infeasibilites)")
println("non ideal infeasibilities: $(num_non_ideal_infeasibilites)")