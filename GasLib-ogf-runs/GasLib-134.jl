include("../src/NGSteady.jl")

include("helper.jl")


zip_file = "GasLib-data/json/GasLib-134.zip"
nomination_cases_file = "GasLib-data/data/nomination_files/GasLib-134.json"
apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!]

cases, num_cases = read_nomination_cases(nomination_cases_file)

for case in cases 
    # ideal run
    @info "case: $(case)"
    @info "slack pressure computation started"
    slack_pressure_data = compute_slack_pressure(zip_file, case; delta = 0.001)
    @info "slack pressure computation ended"
    slack_pressure = slack_pressure_data.slack_pressure 
    net_ideal = slack_pressure_data.net 
    gaslib_134_ogf_ideal = run_ogf(net_ideal)
    pretty_table(gaslib_134_ogf_ideal.stats, title = "GasLib-134 ideal run stats")    
    p = slack_pressure * nominal_values(net_ideal, :pressure)

    # simple cnga run 
    # net_simple_cnga = create_network(zip_file, case, 
    #     apply_on_data = apply_on_data, eos = :simple_cnga,
    #     slack_pressure = p)
    @info "slack pressure computation started"
    slack_pressure_data = compute_slack_pressure(zip_file, case; delta = 0.0001, eos=:simple_cnga)
    @info "slack pressure computation ended"
    slack_pressure = slack_pressure_data.slack_pressure 
    net_simple_cnga = slack_pressure_data.net 
    gaslib_134_ogf_simple_cnga = run_ogf(net_simple_cnga)
    pretty_table(gaslib_134_ogf_simple_cnga.stats, title = "GasLib-134 non-ideal run stats")
    break
end 