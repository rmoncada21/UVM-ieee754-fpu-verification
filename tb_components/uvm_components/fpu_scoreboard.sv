class fpu_scoreboard_c extends uvm_scoreboard;
	`uvm_component_utils(fpu_scoreboard_c)
	
	// uvm_tlm_analysis_fifo ¿?
	uvm_analysis_imp #(fpu_seq_item_c, fpu_scoreboard_c) tlm_scb_aimp;

	function new(string name="fpu_scoreboard_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new


	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		tlm_scb_aimp = new("tlm_scb_aimp", this);

		`uvm_info(this.get_type_name(),
				"TLM - uvm_analysis_imp: tlm_scb_aimp creado",
				UVM_LOW)
	endfunction :  build_phase;

	virtual function void start_of_simulation_phase(uvm_phase phase);
		super.start_of_simulation_phase(phase);
		`uvm_info(this.get_type_name(),
			"Scoreboard, modelo de referencia DPI-C cargado",
			UVM_LOW)

	endfunction : start_of_simulation_phase

	// TODO: hacer report phase
	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
	endfunction : report_phase


	// TODO: implementar funcion write
	virtual task write(fpu_seq_item_c item);
		`uvm_info(this.get_type_name(),
			" - ",
			UVM_LOW);
	endtask

endclass: fpu_scoreboard_c