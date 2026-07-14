class fpu_seq_item_c extends uvm_sequence_item;
	// entradas 
	rand fpu_op_code_e op_code_i;
	rand fpu_r_mode_e r_mode_i;
	rand logic [C_FP_WIDTH-1:0] fp_a_i;
	rand logic [C_FP_WIDTH-1:0] fp_b_i;
	rand logic [C_FP_WIDTH-1:0] fp_c_i;

	// salidas
	logic [C_FP_WIDTH-1:0] fp_result_o;
	logic cmp_result_o;
	logic overflow_o;
	logic underflow_o;
	logic invalid_o;


	// registro de las variables en UVM
	`uvm_object_utils_begin(fpu_seq_item_c)
		// entradas
		`uvm_field_enum(fpu_op_code_e, op_code_i, UVM_ALL_ON)
		`uvm_field_enum(fpu_r_mode_e, r_mode_i,   UVM_ALL_ON)
		`uvm_field_int(fp_a_i, 					  UVM_ALL_ON | UVM_HEX)
		`uvm_field_int(fp_b_i, 					  UVM_ALL_ON | UVM_HEX)
		`uvm_field_int(fp_c_i, 					  UVM_ALL_ON | UVM_HEX)
		// salidas
		`uvm_field_int(fp_result_o, 			  UVM_ALL_ON | UVM_HEX)
		`uvm_field_int(cmp_result_o, 			  UVM_ALL_ON)
		`uvm_field_int(overflow_o,  			  UVM_ALL_ON)
		`uvm_field_int(underflow_o,  			  UVM_ALL_ON)
		`uvm_field_int(invalid_o,  				  UVM_ALL_ON)
	`uvm_object_utils_end

	// constructor
	function new(string name = "fpu_seq_item_c");
		super.new(name);
	endfunction


	// constraints



endclass: fpu_seq_item_c