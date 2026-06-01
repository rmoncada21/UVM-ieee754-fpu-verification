class fpu_base_sequence_c extends uvm_sequence #(fpu_seq_item_c);
	`uvm_object_utils(fpu_base_sequence_c);

	rand int num_items;


	constraint c_num_items {
		num_items inside {[100:200]};
	}

	function new(string name="fpu_base_sequence_c");
		super.new(name);
	endfunction : new

	virtual task body();
		`uvm_info(this.get_type_name(),
			$sformatf("body aleatorio: %0d items", num_items),
			UVM_LOW)
		
		repeat(num_items) begin
			this.req = fpu_seq_item_c::type_id::create();
			// se mandan item al sequencer
			this.start_item(req);
			if(!req.randomize()) begin
				`uvm_error(this.get_type_name(),
					"Fallo en randomize() base sequence")
			end
			this.finish_item(req);
		end

	endtask: body
	
endclass: fpu_base_sequence_c