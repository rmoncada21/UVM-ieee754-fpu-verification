/*
 * File:    fpu_base_sequence.sv
 * - Project:  FPU RV32F  Verificación funcional UVM
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
		soft num_items_rand inside { [100:200] };
	}
	
	// Prototipos de funiones del base sequence
	extern function new(string name="fpu_base_sequence_c");
	extern virtual task body();

	// Prototipos de generdores de operandos IEEE 754
	// signo positivo:0 - negativo: -1
	extern protected function logic [C_FP_WIDTH-1:0] gen_operando( fpu_clase_operando_e clase, int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_cero(int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_subnormal(int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_normal(int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_inf(int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_qnan(int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_snan(int signo = -1);

endclass : fpu_base_sequence_c

// Implementación de las funciones
// constructor de la clase
function fpu_base_sequence_c::new(string name="fpu_base_sequence_c");
	super.new(name);
	// instanciar el contenedor de los constraints
	item_constraints = fpu_seq_constraints_c::type_id::create("item_constraints");
endfunction : new

// body
task fpu_base_sequence_c::body();
	fpu_seq_item_c item;
	`uvm_info(get_type_name(),
		$sformatf("Inicio de la secuencia: %0d items", 
		num_items_rand), UVM_LOW)
		
	for(int i=0; i<num_items_rand; i++) begin
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

// Function: gen_operando
// Nucleo comun: activa la clase pedida en item_constraints, fija el knob de signo,
// randomiza y empaqueta. Sin bloque with: evita el sombreado entre
// signo_rand de la secuencia y signo_rand de item_constraints.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_operando(
		fpu_clase_operando_e clase, int signo);
	item_constraints.activar_clase(clase);
	item_constraints.signo_forzado = signo;
	
	if (!item_constraints.randomize())
		`uvm_error(get_type_name(),
			$sformatf("Fallo el randomize de gen_operando (clase=%s)", 
			clase.name()))

	return item_constraints.operando();
endfunction : gen_operando

// Cero con signo
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_cero(int signo);
	return gen_operando(CLASE_CERO, signo);
endfunction : gen_cero

// Subnormal
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_subnormal(int signo);
	return gen_operando(CLASE_SUBNORMAL, signo);
endfunction : gen_subnormal

// Normal
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_normal(int signo);
	return gen_operando(CLASE_NORMAL, signo);
endfunction : gen_normal

// Infinito
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_inf(int signo);
	return gen_operando(CLASE_INF, signo);
endfunction : gen_inf

// qNaN
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_qnan(int signo);
	return gen_operando(CLASE_QNAN, signo);
endfunction : gen_qnan

// sNaN
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_snan(int signo);
	return gen_operando(CLASE_SNAN, signo);
endfunction : gen_snan