class fpu_test_arith_normal_c extends fpu_base_test_c;
    `uvm_component_utils(fpu_test_arith_normal_c)

    function new(string name = "fpu_test_arith_normal_c", uvm_componet parent=null);
        super.new(name);
    endfunction : new

    task run_phase(uvm_phase phase);
        `uvm_phase(phase);
        fpu_sequence_arith_normal_c seq_arith_normal;
        phase.raise_objection(this, "fpu_sequence_arith_normal_c: estimulo enviado");
            seq_arith_normal = fpu_sequence_arith_normal_c::type_id::create("seq_arith_normal");
            seq_artih_normal.start(fpu_env.fpu_agent.fpu_sequencer);
        phase.drop_objection(this, "fpu_sequence_arith_normal_c: estimulo completo");
    endtask : run_phase

endclass