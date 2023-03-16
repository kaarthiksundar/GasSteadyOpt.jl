function initialize_simulator(net::NetworkData, solution::Solution)::SteadySimulator 

    ref = _build_ref(net, solution, ref_extensions= [
        DataProcessing._add_pipe_info_at_nodes!,
        DataProcessing._add_compressor_info_at_nodes!,
        DataProcessing._add_control_valve_info_at_nodes!,
        DataProcessing._add_valve_info_at_nodes!,
        DataProcessing._add_resistor_info_at_nodes!,
        DataProcessing._add_loss_resistor_info_at_nodes!,
        DataProcessing._add_short_pipe_info_at_nodes!,
        _add_index_info!,
        _add_incident_dofs_info_at_nodes!
        ]
    )

    return SteadySimulator(net, ref, solution)
end 