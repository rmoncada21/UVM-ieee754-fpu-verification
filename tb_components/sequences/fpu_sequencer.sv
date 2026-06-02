class fpu_sequencer_c extends uvm_sequencer #(fpu_seq_item_c);
	`uvm_component_utils(fpu_sequencer_c)

	function new(string name="fpu_sequencer_c", uvm_component parent);
		super.new(name, parent);
	endfunction: new

endclass: fpu_sequencer_c