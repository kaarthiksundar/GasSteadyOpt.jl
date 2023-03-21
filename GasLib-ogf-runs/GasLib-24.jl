include("../src/NGSteady.jl")

zip_file = "GasLib-data/json/GasLib-24.zip"
nomination_case = "GasLib-24"
apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!]

# ideal run
@info "slack pressure computation started"
slack_pressure_data = compute_slack_pressure(zip_file, nomination_case)
@info "slack pressure computation ended"
slack_pressure = slack_pressure_data.slack_pressure 
net_ideal = slack_pressure_data.net 
# test run to get rid of precompiling run time
run_ogf(net_ideal) 
# actual run 
gaslib_24_ogf_ideal = run_ogf(net_ideal)
pretty_table(gaslib_24_ogf_ideal.stats, title = "GasLib-24 ideal run stats")
p = slack_pressure * nominal_values(net_ideal, :pressure)

# simple cnga run
net_simple_cnga = create_network(zip_file, nomination_case, 
    apply_on_data = apply_on_data, eos = :simple_cnga,
    slack_pressure = p)
gaslib_24_ogf_simple_cnga = run_ogf(net_simple_cnga)
pretty_table(gaslib_24_ogf_simple_cnga.stats, title = "GasLib-24 non-ideal run stats")


