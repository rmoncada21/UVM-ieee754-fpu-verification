class fpu_base_test_c extends uvm_test;
	`uvm_components_utils(fpu_base_test_c);

	// instanciar ambiente
	fpu_env_c fpu_env;

	function new(string name="fpu_base_test_c", uvm_component parent=null);
		super.new(name, parent);
	endfunction;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		fpu_env = fpu_env_c::type_id::create(fpu_env, this);
		// mostrar mensajes de creado
	endfunction: build_phase

	virtual function void end_of_elaboration_phase (uvm_phase phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		`uvm_info("BASE_TEST", 
			"No EJECUTA SECUENCIAS, 
			UVM_LOW");
		phase.drop_objection(this);
	endtask

endclass