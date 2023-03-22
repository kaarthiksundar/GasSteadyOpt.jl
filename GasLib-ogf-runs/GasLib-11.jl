include("../src/NGSteady.jl")

zip_file = "GasLib-data/json/GasLib-11.zip"
nomination_case = "GasLib-11"
apply_on_data::Vector{Function} = [strengthen_flow_bounds!, modify_entry_nominations!]

# ideal run
@info "slack pressure computation started"
slack_pressure_data = compute_slack_pressure(zip_file, nomination_case, eos = :simple_cnga)
@info "slack pressure computation ended"
slack_pressure = slack_pressure_data.slack_pressure 
net_simple_cnga = slack_pressure_data.net 
# test run to get rid of precompiling run time
run_ogf(net_simple_cnga) 
# actual run 
gaslib_11_ogf_simple_cnga = run_ogf(net_simple_cnga)
pretty_table(gaslib_11_ogf_simple_cnga.stats, title = "GasLib-11 non-ideal run stats")
# GasLib-11 ideal slack pressure causes ub violation in non ideal run 
p = slack_pressure * nominal_values(net_simple_cnga, :pressure)

# simple cnga run
net_ideal = create_network(zip_file, nomination_case, 
    apply_on_data = apply_on_data, slack_pressure = p)
gaslib_11_ogf_ideal = run_ogf(net_ideal)
pretty_table(gaslib_11_ogf_ideal.stats, title = "GasLib-11 ideal run stats")


