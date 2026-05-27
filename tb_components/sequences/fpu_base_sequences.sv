class fpu_base_sequence_c extends uvm_sequence #(fpu_seq_item_c);
	`uvm_object_utils(fpu_base_sequence_c);

	rand int num_transactions;


	constraint c_num_transactions {
		num_transactions inside {[100:200]};
	}

	function new(string name="fpu_base_sequence_c");
		super.new(name);
	endfunction: new

endclass: fpu_base_sequence_c