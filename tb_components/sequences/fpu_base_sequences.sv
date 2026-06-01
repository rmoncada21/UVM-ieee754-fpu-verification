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

	// Prototipos de generdores
	// 0: positivo - 1: negativo
	extern protected function logic [31:0] gen_cero(bit signo = 1'b0);
	extern protected function logic [31:0] gen_subnormal(bit signo = 1'b0);
	extern protected function logic [31:0] gen_normal(bit signo = 1'b0);
	extern protected function logic [31:0] gen_inf(bit signo = 1'b0);
	extern protected function logic [31:0] gen_qnan(bit signo = 1'b0);
	extern protected function logic [31:0] gen_snan(bit signo = 1'b0);
	
endclass: fpu_base_sequence_c

// Cero con signo.
function logic [31:0] fpu_base_sequence_c::gen_cero(bit signo = 1'b0);
	logic [7:0] exponent;
	logic [22:0] mantissa;
	
	return {signo, exponent, mantissa};
endfunction: gen_cero

// Subnormal: exponente cero, mantisa distinta de cero
function logic [31:0] fpu_base_sequence_c::gen_subnormal(bit signo = 1'b0);
	logic [7:0] exponent;
	logic [22:0] mantissa;
	exponent = 8'h00;
	mantissa = 32'($urandom_range(23'h7F_FFFF,23'd1));

	return {signo, exponent, mantissa};
endfunction: gen_subnormal

// Normmal: exponente en [1,254], mantisa cualquiera
function logic [31:0] fpu_base_sequence_c::gen_normal(bit signo = 1'b0);
	logic [7:0] exponent;
	logic [22:0] mantissa;
	exponent = 8'($urandom_range(8'd254,8'd1));
	mantissa = 23'($urandom_range(23'h7F_FFFF,0));

	return{signo, exponent, mantissa};
endfunction: gen_normal

// Infinito: exponente todos unos, mantisa cero 
function logic [31:0] fpu_base_sequence_c::gen_inf(bit signo = 1'b0);
	logic [7:0] exponent;
	logic [22:0] mantissa;
	exponent = 8'hFF;
	mantissa = 32'h00_000;

	return {signo, exponent, mantissa};
endfunction: gen_inf

// qNaN: exponente todos en unos, bit alto de mantisa en 1 (quiet)
function logic [31:0] fpu_base_sequence_c::gen_qnan(bit signo = 1'b0);
	logic [7:0] exponent;
	logic mantissa;
	logic [21:0] payload;
	exponent = 8'hFF;
	mantissa = 1'b1;
	payload = 22'($urandom);

	return{signo, exponent, mantissa, payload};
endfunction: gen_qnan

// signaling not a number
// sNaN: exponentes todos en unos, bit alto de mantisa en 0, resto disinto de cero
function logic [31:0] fpu_base_sequence_c::gen_snan(bit signo = 1'b0);
	logic [7:0] exponent;
	logic mantissa;
	logic [21:0] payload;
	exponent = 8'hFF;
	mantissa = 1'b0;
	payload = 22'($urandom_range(22'h3F_FFFF,22'd1));

	return{signo, exponent, mantissa, payload};
endfunction: gen_snan
