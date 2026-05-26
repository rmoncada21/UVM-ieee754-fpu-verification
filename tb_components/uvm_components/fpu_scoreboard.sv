class fpu_scoreboard_c extends uvm_scoreboard;
	`uvm_component_utils(fpu_scoreboard_c);

	function new(string name="fpu_scoreboard_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new


	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

	endfunction :  build_phase;

endclass: fpu_scoreboard_c