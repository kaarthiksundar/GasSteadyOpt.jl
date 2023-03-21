include("../src/NGSteady.jl")

zip_file = "GasLib-data/json/GasLib-24.zip"
nomination_case = "GasLib-24"

# ideal run
@info "slack pressure computation started"
slack_pressure_data = compute_slack_pressure(zip_file, nomination_case)
@info "slack pressure computation ended"
slack_pressure = slack_pressure_data.slack_pressure 
net_ideal = slack_pressure_data.net 
gaslib_24_ogf_ideal = run_ogf(net_ideal)
pretty_table(gaslib_24_ogf_ideal.stats, title = "GasLib-24 ideal run stats")

# simple cnga run
@info "slack pressure computation started"
slack_pressure_data = compute_slack_pressure(zip_file, nomination_case; eos = :simple_cnga)
@info "slack pressure computation ended"
slack_pressure = slack_pressure_data.slack_pressure 
net_simple_cnga = slack_pressure_data.net 
gaslib_24_ogf_simple_cnga = run_ogf(net_simple_cnga)
pretty_table(gaslib_24_ogf_simple_cnga.stats, title = "GasLib-24 non-ideal run stats")


