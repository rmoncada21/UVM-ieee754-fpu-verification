class fpu_driver_c extends uvm_driver #(fpu_seq_item_c);
	`uvm_component_utils(fpu_driver_c);

	// handler de la interfas con Dut
	virtual fpu_if bif; // bus interface

	// comunicacion con el scoreboard

	// constructor
	function new(string name="fpu_driver_c", uvm_component parent);
		super.new(name, parent);
	endfunction

	// UVM build phase
	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if( !uvm_config_db#(virtual fpu_if)::get(this, "", "vif", bif) ) begin
			`uvm_fatal( get_type_name(), 
				"No se pudo obtener vif desde uvm_db_config" )
		end



	endfunction: build_phase

	// Task: run_phase
	// Lazo principal del driver:
	// 1. Espera un item del sequencer.
	// 2. Llama drive_item().
	// 3. Publica la transacción al scoreboard por drv_ap.
	virtual task run_phase(uvm_phase phase);
		fpu_seq_item_c transaction;
		
		forever begin
			seq_item_port.get_next_item(transaction);

			// revisar integradad del paquete
			if(transaction == null) begin
				`uvm_error(get_type_name(), "Se recibio un transaction nulo") 
				seq_item_port.item_done();
				continue;
			end

			drive_item(transaction);
			seq_item_port.item_done();

		end

	endtask: run_phase


	task drive_item(fpu_seq_item_c transaction);
		@(posedge bif.clk);
			bif.op_code_i <= transaction.op_code;
			bif.r_mode_i <= transaction.r_mode;
			bif.fp_a_i <= transaction.fp_a_i;
			bif.fp_b_i <= transaction.fp_b_i;
			bif.fp_c_i <= transaction.fp_c_i;
	endtask: drive_item

endclass: fpu_driver_c