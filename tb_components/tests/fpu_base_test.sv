class fpu_base_test_c extends uvm_test;
	`uvm_component_utils(fpu_base_test_c);

	// handler/puntero al ambiente
	fpu_env_c fpu_env;

	function new(string name="fpu_base_test_c", uvm_component parent=null);
		super.new(name, parent);
	endfunction;

function void end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);

  // 1. Primero validamos que el environment y el agente existan (no sean nulos)
  // Nota: Ajusta 'env' y 'agnt' a los nombres de instancia reales de tus variables
  if (env.agnt == null) begin
    `uvm_fatal("EOL_ERR", "El Agente no fue creado. Revisa el build_phase del env.")
  end

  // 2. Verificamos el estado de actividad del agente
  if (env.agnt.get_is_active() == UVM_ACTIVE) begin
    `uvm_info("TEST_CHK", "Confirmado: El Agente está configurado como ACTIVO.", UVM_LOW)
  end else if (env.agnt.get_is_active() == UVM_PASSIVE) begin
    `uvm_info("TEST_CHK", "Confirmado: El Agente está configurado como PASIVO.", UVM_LOW)
  end else begin
    `uvm_error("TEST_CHK", "Estado del Agente desconocido.")
  end

  // 3. Imprimir la topología (como lo tenías comentado, es una gran práctica)
  uvm_top.print_topology();
  
endfunction

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
		
		`uvm_info(get_type_name(),
				"FPU_ENV creado desde fpu_base_test",
				UVM_LOW);

		// variable para crear el agente activo
		uvm_config_db#(uvm_active_passive_enum)::set(
			this, "fpu_env.fpu_agent", "is_active", UVM_ACTIVE);

	endfunction: build_phase

	virtual function void end_of_elaboration_phase (uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        
        `uvm_info(get_type_name(),
            $sformatf(" listo. Componentes=%0d",
                      get_type_name(),
                      uvm_top.get_num_children()),
            UVM_LOW)

        if(fpu_env.fpu_agent == null) begin
        	// EO_ERR: End Of Elaboration Error 
        	`uvm_fatal("EO_ERR",
        			"El agente no ha sido creado, revisar el build_phase del fpu_agent");	
        end

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