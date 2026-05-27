class fpu_monitor_c extends uvm_monitor;
	`uvm_component_utils(fpu_monitor_c);
	virtual fpu_if bif;

	// uvm TLM emisor 
	uvm_analysis_port #(fpu_seq_item_c) tlm_mon_ap; // monitor analysis port = mon_ap


	// constructor
	function new(string name="fpu_monitor_c", uvm_component parent);
		super.new(name, parent);
		tlm_mon_ap = new("tlm_mon_ap", this);
	endfunction : new

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if( !uvm_config_db#(virtual fpu_if)::get(this, "", "vif", bif) ) begin
			`uvm_fatal( get_type_name(), 
				"Monitor: No se pudo obtener vif desde uvm_db_config" )
		end

	endfunction

	virtual task run_phase(uvm_phase phase);
		fpu_seq_item_c item;

		item = fpu_seq_item_c::type_id::create("item", this);

		forever begin : forever_loop
			@(posedge bif.clk);
				// rastrear las entradas
				item.op_code_i = fpu_op_code_e'(bif.op_code_i);
				item.r_mode_i = fpu_r_mode_e'(bif.r_mode_i);
				item.fp_a_i = bif.fp_a_i;
				item.fp_b_i = bif.fp_b_i;
				item.fp_c_i = bif.fp_c_i;
				// rastrear las salidas
				item.fp_result_o = bif.fp_result_o;
				item.cmp_result_o = bif.cmp_result_o;
				item.overflow_o = bif.overflow_o;
				item.underflow_o = bif.underflow_o;
				item.invalid_o = bif.invalid_o;
				tlm_mon_ap.write(item);
				// agregar funcin para mostrar los resultados
		end: forever_loop

	endtask: run_phase

endclass: fpu_monitor_c