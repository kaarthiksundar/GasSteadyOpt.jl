include("../../src/NGSteady.jl")

include("helper.jl")


zip_file = "GasLib-data/json/GasLib-4197.zip"
nomination_cases_file = "GasLib-data/data/nomination_files/GasLib-4197.json"
apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!]
instance = "\nGasLib-4197"
cases, num_cases = read_nomination_cases(nomination_cases_file)

for case in cases 
    # ideal run 
    net_ideal = parse_network_data(zip_file, case,
    apply_on_data = apply_on_data, 
    eos = :ideal 
    )
    result_ideal = run_ogf(net_ideal)
    pretty_table(result_ideal.stats, title = instance * " ideal run stats")

    # non ideal run 
    net_non_ideal = parse_network_data(zip_file, case,
    apply_on_data = apply_on_data, 
    eos = :simple_cnga
    )
    result_non_ideal = run_ogf(net_non_ideal)
    pretty_table(result_non_ideal.stats, title = instance * " non ideal run stats")
end 