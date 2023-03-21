include("../src/NGSteady.jl")

zip_file = "GasLib-data/json/GasLib-11.zip"
nomination_case = "GasLib-11"

println("... slack pressure data computation started ...")
slack_pressure_data = compute_slack_pressure(zip_file, nomination_case)
println("... slack pressure data computation ended ...")
slack_pressure = slack_pressure_data.slack_pressure 
net = slack_pressure_data.net 

sopt = initialize_optimizer(net)
run_lp!(sopt)
run_misoc!(sopt)
run_minlp!(sopt)
println("MINLP solve time: $(solve_time(sopt.nonlinear_full.model)) sec.")
println("MISOC solve time: $(solve_time(sopt.misoc_relaxation.model)) sec.")
println("LP solve time: $(solve_time(sopt.linear_relaxation.model)) sec.")
ss, sr = run_simulation_with_lp_solution!(net, sopt)
println("Simulation time: $(sr.time) sec.")
feasibility = is_solution_feasible!(ss)
println("Globally optimal: $(feasibility |> first)")


