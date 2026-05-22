class fpu_monitor_c extends uvm_monitor;
	`uvm_component_utils(fpu_monitor_c);
	virtual fpu_if bif;

	// constructor
	function new(string name="fpu_monitor_c", uvm_component parent);
		super.new(name, parent);
	endfunction : new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if( !uvm_config_db#(virtual fpu_if)::get(this, "", "vif", bif) ) begin
			`uvm_fatal( get_type_name(), 
				"Monitor: No se pudo obtener vif desde uvm_db_config" )
		end

	endfunction

	virtual task run_phase(uvm_phase phase);
		fpu_seq_item_c transaction;

		transaction = fpu_seq_item_c::type_id::create("transaction", this);

		forever begin
			@(posedge bif.clk);
				// rastrear las entradas
				transaction.op_code_i = fpu_op_code_e'(bif.op_code_i);
				transaction.r_mode_i = fpu_r_mode_e'(bif.r_mode_i);
				transaction.fp_a_i = bif.fp_a_i;
				transaction.fp_b_i = bif.fp_b_i;
				transaction.fp_c_i = bif.fp_c_i;
				// rastrear las salidas
				transaction.fp_result_o = bif.fp_result_o;
				transaction.cmp_result_o = bif.cmp_result_o;
				transaction.overflow_o = bif.overflow_o;
				transaction.underflow_o = bif.underflow_o;
				transaction.invalid_o = bif.invalid_o;

				// agregar funcin para mostrar los resultados
		end

	endtask: run_phase

endclass: fpu_monitor_c