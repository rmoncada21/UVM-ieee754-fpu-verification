class fpu_scoreboard_c extends uvm_scoreboard;
	`uvm_component_utils(fpu_scoreboard_c);
	
	// uvm tlm receptor; recibe desde *_port (monitor)
	uvm_analysis_imp #(fpu_seq_item_c, fpu_scoreboard_c) tlm_mon_aimp;

	function new(string name="fpu_scoreboard_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new


	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

	endfunction :  build_phase;

	virtual function void report_phase(uvm_phase phase);
			super.report_phase(phase);
	endfunction : report_phase


	virtual task write(fpu_seq_item_c item);
	endtask

endclass: fpu_scoreboard_c