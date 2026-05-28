class fpu_base_test_c extends uvm_test;
	`uvm_component_utils(fpu_base_test_c);

	// handler/puntero al ambiente
	fpu_env_c fpu_env;

	function new(string name="fpu_base_test_c", uvm_component parent=null);
		super.new(name, parent);
	endfunction;

	/* Verificar conexiones, verificar que existen componentes
	validar configuraciones, revisar topologa */
	// function void end_of_elaboration_phase(uvm_phase phase);
    // 	super.end_of_elaboration_phase(phase);

    // 	if (fpu_env.fpu_agent == null)
    //     	`uvm_fatal("EOL", "Agent no fue creado")

    // 	uvm_top.print_topology();
	// endfunction

	/* Imprimir banners, mostrar configuración aplicada al run.
	como por ejemplos, mostrar seed del test 
	configurar verbosity, setear timeouts, activar debug
	ajustes gloables de ejecucion */

	// function void start_of_simulation_phase(uvm_phase phase);
    // super.start_of_simulation_phase(phase);

    // // imprime todo por debajo de UVM_HIGH 
    // 	uvm_top.set_report_verbosity_level(UVM_HIGH);
    //	// uvm_top.print_topology();
    // $display({`BOLD_CYAN,
    //       "\n+------------------------------------------+\n",
    //       "¦   FPU RV32F  VFCI                    ¦\n",
    //       "¦   Test: %-34s¦\n", get_type_name(),
    //       "+------------------------------------------+",
    //       `RESET});
	// endfunction


	/* build phase
	instanciar los hijos del componente via factory de UVM */
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		// creacin del ambiente
		fpu_env = fpu_env_c::type_id::create("fpu_env", this);
		
		`uvm_info("FPU_BASE_TEST",
				"FPU_ENV creado desde fpu_base_test",
				UVM_LOW);

		`CUSTOM

	endfunction: build_phase

	virtual function void end_of_elaboration_phase (uvm_phase phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		`uvm_info("BASE_TEST", 
			"No EJECUTA SECUENCIAS",
			UVM_LOW);
		phase.drop_objection(this);
	endtask

endclass