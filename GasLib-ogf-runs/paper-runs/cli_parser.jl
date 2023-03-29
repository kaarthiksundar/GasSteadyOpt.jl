function parse_cli_args()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--zipfile", "-z"
            help = "zipfile path relative to root directory"
            arg_type = String 
            default = "GasLib-data/json/GasLib-11.zip"
        "--nominationcase", "-n"
            help = "name of nomination case"
            arg_type = String 
            default = "GasLib-11"
        "--timelimit", "-t"
            help = "time limit for minlp in seconds"
            arg_type = Float64 
            default = 1000.0
        "--resultfolder", "-r"
            help = "folder to save the results"
            arg_type = String 
            default = "GasLib-ogf-runs/paper-runs/output/GasLib-11"
    end
    return parse_args(s)
end

get_cli_args() = parse_cli_args()