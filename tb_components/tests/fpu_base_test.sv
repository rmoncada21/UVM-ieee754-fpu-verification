class fpu_base_test_c extends uvm_test;
	`uvm_component_utils(fpu_base_test_c);

	// handler/puntero al ambiente
	fpu_env_c fpu_env;

	function new(string name="fpu_base_test_c", uvm_component parent=null);
		super.new(name, parent);
	endfunction;

	/* build phase
	instanciar los hijos del componente via factory de UVM */
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		// creacin del ambiente
		fpu_env = fpu_env_c::type_id::create("fpu_env", this);
		
		`uvm_info(this.get_type_name(),
				"FPU_ENV creado desde fpu_base_test",
				UVM_LOW);

		// variable para crear el agente activo
		uvm_config_db#(uvm_active_passive_enum)::set(
			this, "fpu_env.fpu_agent", "is_active", UVM_ACTIVE);

	endfunction: build_phase

	virtual function void end_of_elaboration_phase (uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        
        `uvm_info(this.get_type_name(),
            	$sformatf(" listo. Numeros de Componentes=%0d",uvm_top.get_num_children()),
            	UVM_LOW)

        if(fpu_env.fpu_agent == null) begin
        	// EO_ERR: End Of Elaboration Error 
        	`uvm_fatal("EO_ERR",
        			"El agente no ha sido creado, revisar el build_phase del fpu_agent");	
        end

        if(fpu_env.fpu_agent.get_is_active() == UVM_ACTIVE) begin
        	`uvm_info(this.get_type_name(),
        		"el agente esta configurado como activo",
        		UVM_LOW)
        end else if ( fpu_env.fpu_agent.get_is_active() == UVM_PASSIVE ) begin
        	`uvm_info(this.get_type_name(),
        		"el agente esta configurado como pasivo",
        		UVM_LOW)
        end else begin
        	`uvm_error(this.get_type_name(),
        		"el agente esta configurado como DESCONOCIDO")
        end

    	`uvm_info(this.get_type_name(),
    			"Topología del ambiente UVM:",
    			UVM_LOW)
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

    /* Imprimir banners, mostrar configuración aplicada al run.
	como por ejemplos, mostrar seed del test 
	configurar verbosity, setear timeouts, activar debug
	ajustes gloables de ejecucion */
    virtual function void start_of_simulation_phase(uvm_phase phase);
    	super.start_of_simulation_phase(phase);
    	$timeformat(0, 6, " s", 12);
    	// uvm_top.phase_timeout = 10s;
    	// Mostrar banner
    	`CUSTOM_MSG("============================================================")
    	`CUSTOM_MSG("  FPU RV32F  ·  Ambiente UVM de verificación funcional")
	    `CUSTOM_MSG("  DUT: fpu_alu  ·  IEEE 754-2008 binary32")
	    `CUSTOM_MSG("============================================================")

	    `CUSTOM_INFO("FPU_TEST",
	                 $sformatf("Test     : %s", get_type_name()),
	                 `BOLD)
	    `CUSTOM_INFO("FPU_TEST",
	                 $sformatf("Semilla  : %0h", $get_initial_random_seed()),
	                 `BOLD)
	    `CUSTOM_INFO("FPU_TEST",
	                 $sformatf("Timeout  : %0t", uvm_top.phase_timeout),
	                 `BOLD)
	    `CUSTOM_MSG("============================================================")
	endfunction : start_of_simulation_phase


	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		`uvm_info(this.get_type_name(), 
			"No EJECUTA SECUENCIAS",
			UVM_LOW);
		phase.drop_objection(this);
	endtask

endclass