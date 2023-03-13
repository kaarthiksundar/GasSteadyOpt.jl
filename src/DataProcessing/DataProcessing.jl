module DataProcessing

    import JSON
    import ZipFile

    include("json.jl")
    include("ref.jl")
    include("types.jl")
    include("network_data_parser.jl")
    include("network_data_processors.jl")
    
    include("unit_conversion/unit_convertor_utils.jl")
    include("unit_conversion/to_si.jl")
    include("unit_conversion/to_english.jl")
    include("unit_conversion/to_pu.jl")
    include("unit_conversion/unit_convertors.jl")

    include("eos.jl")
    
    include("parsers.jl")

    export NetworkData

    const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]
    for sym in names(@__MODULE__, all = true)
        sym_string = string(sym)
        if sym in _EXCLUDE_SYMBOLS || startswith(sym_string, "_")
            continue
        end
        if !(
            Base.isidentifier(sym) || (startswith(sym_string, "@") && Base.isidentifier(sym_string[2:end]))
        )
            continue
        end
        @eval export $sym
    end

end