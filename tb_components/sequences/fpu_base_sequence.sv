/*
 * File:    fpu_base_sequence.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia base del ambiente. Su body() envía num_items_rand
 *   transacciones completamente aleatorias (smoke). Expone a las
 *   secuencias hijas los generadores dirigidos de operandos IEEE 754
 *   (gen_cero, gen_subnormal, gen_normal, gen_inf, gen_qnan, gen_snan),
 *   construidos sobre el contenedor de constraints item_constraints
 *   (fpu_seq_constraints_c) con encendido/apagado por clase.
 *
 * Dependencies:
 *   fpu_seq_item.sv, fpu_seq_constraints.sv, fpu_types_contraints_pkg.sv
 */

class fpu_base_sequence_c extends uvm_sequence #(fpu_seq_item_c);
	`uvm_object_utils(fpu_base_sequence_c)

	// knobs de la secuencia
	rand int num_items_rand;
	rand bit signo_rand; // signo compartido opcional

	// generador de operandos de constraints por clase IEEE 754
	protected fpu_seq_constraints_c item_constraints;

	// cantidad de items; soft para que los derivados lo redefinan
	constraint cn_num_items {
		soft num_items_rand inside {
			[100 : 200]
		};
	}
	
	function new(string name="fpu_base_sequence_c");
		super.new(name);
		// instanciar el contenedor de los constraints
		item_constraints = fpu_seq_constraints_c::type_id::create("item_constraints");
	endfunction : new

	// body
	virtual task body();
		fpu_seq_item_c item;
		
		`uvm_info(get_type_name(),
			$sformatf("Inicio de la secuencia: %0d items", 
			num_items_rand), UVM_LOW)
		
		for(int i=0, i<num_items_rand; i++) begin
			item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));
			start_item(item);

			// operacion, modo de rodondeo y operandos aleatorios
			if(!item.randomize()) begin
				`uvm_error(get_type_name(),
					$sformatf("Falló el randomize del item %0d", i))
			end
			finish_item(item);

			`uvm_info(get_type_name(), 
				$sformatf("Item %0d enviado", i), UVM_MEDIUM)
		end

		`uvm_info(get_type_name(), 
			"Fin de Secuencia", UVM_MEDIUM)
	endtask :  body

	// Prototipos de generdores de operandos IEEE 754
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
	exponent = 	8'h00;
	mantissa = 23'h00_000;

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
