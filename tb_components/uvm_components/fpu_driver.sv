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
				"Driver: No se pudo obtener vif desde uvm_db_config" )
		end

	endfunction: build_phase

	// Task: run_phase
	// Lazo principal del driver:
	// 1. Espera un item del sequencer.
	// 2. Llama drive_item().
	// 3. Publica la transacción al scoreboard por drv_ap.
	virtual task run_phase(uvm_phase phase);
		fpu_seq_item_c item;
		
		forever begin
			seq_item_port.get_next_item(item);

			// revisar integradad del paquete
			if(item == null) begin
				`uvm_error(get_type_name(), "Se recibio un item nulo") 
				seq_item_port.item_done();
				continue;
			end

			drive_item(item);
			seq_item_port.item_done();

		end

	endtask: run_phase


	task drive_item(fpu_seq_item_c item);
		@(posedge bif.clk);
			bif.op_code_i <= item.op_code_i;
			bif.r_mode_i <= item.r_mode_i;
			bif.fp_a_i <= item.fp_a_i;
			bif.fp_b_i <= item.fp_b_i;
			bif.fp_c_i <= item.fp_c_i;
	endtask: drive_item

endclass: fpu_driver_c