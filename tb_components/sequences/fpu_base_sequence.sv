/*
 * File:    fpu_base_sequence.sv
 * Project:  FPU RV32F — Verificación funcional UVM
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
	rand int num_items_rand; // cantidad de items a enviar
	rand bit signo_rand; // signo compartido opcional

	// generador de operandos de constraints por clase IEEE 754
	protected fpu_seq_constraints_c item_constraints; // contenedor de constraints por clase
	// cantidad de items; soft para que los derivados lo redefinan
	constraint cn_num_items {
		soft num_items_rand inside { [1000:2000] };
	}
	
	// Prototipos de funiones del base sequence
	extern function new(string name="fpu_base_sequence_c"); // constructor
	extern virtual task body(); // secuencia smoke de items totalmente aleatorios

	// Prototipos de generdores de operandos IEEE 754
	// signo positivo:0 - negativo: -1
	// extern protected function logic [C_FP_WIDTH-1:0] gen_operando( fpu_clase_operando_e clase, int signo = -1);
	extern protected function logic [C_FP_WIDTH-1:0] gen_operando( fpu_clase_operando_e clase, int signo = -1, int exponente = -1);  // núcleo común de los generadores
	extern protected function logic [C_FP_WIDTH-1:0] gen_cero(int signo = -1); // genera cero
	extern protected function logic [C_FP_WIDTH-1:0] gen_subnormal(int signo = -1); // genera subnormal
	extern protected function logic [C_FP_WIDTH-1:0] gen_normal(int signo = -1); // genera normal
	extern protected function logic [C_FP_WIDTH-1:0] gen_normal_banda(int signo = -1); // genera normal en banda segura
	extern protected function logic [C_FP_WIDTH-1:0] gen_inf(int signo = -1); // genera infinito
	extern protected function logic [C_FP_WIDTH-1:0] gen_qnan(int signo = -1); // genera qNaN
	extern protected function logic [C_FP_WIDTH-1:0] gen_snan(int signo = -1); // genera sNaN

endclass : fpu_base_sequence_c

// Implementación de las funciones
// Function: new
// Constructor de la secuencia base; instancia el contenedor de
// constraints (item_constraints) reutilizado por todos los
// generadores dirigidos de operandos.
function fpu_base_sequence_c::new(string name="fpu_base_sequence_c");
	super.new(name);
	// instanciar el contenedor de los constraints
	item_constraints = fpu_seq_constraints_c::type_id::create("item_constraints");
endfunction : new

// Task: body
// Secuencia smoke: genera y envía num_items_rand transacciones con
// opcode, modo de redondeo y operandos completamente aleatorios.
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
// Núcleo común de los generadores dirigidos: activa la clase de
// operando pedida en item_constraints, fija el knob de signo,
// randomiza y empaqueta el resultado. No usa bloque with, para evitar
// el sombreado entre signo_rand de la secuencia y signo_rand de
// item_constraints.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_operando(
		fpu_clase_operando_e clase, int signo, int exponente);
	item_constraints.activar_clase(clase);
	item_constraints.signo_forzado     = signo;
	item_constraints.exponente_forzado = exponente;
	
	if (!item_constraints.randomize())
		`uvm_error(get_type_name(),
			$sformatf("Fallo el randomize de gen_operando (clase=%s)", 
			clase.name()))

	return item_constraints.operando();
endfunction : gen_operando

// Function: gen_cero
// Genera un operando cero (±0) con el signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_cero(int signo);
	return gen_operando(CLASE_CERO, signo);
endfunction : gen_cero

// Function: gen_subnormal
// Genera un operando subnormal (exponente 0, mantisa != 0) con el
// signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_subnormal(int signo);
	return gen_operando(CLASE_SUBNORMAL, signo);
endfunction : gen_subnormal

// Function: gen_normal
// Genera un operando normal con el signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_normal(int signo);
	return gen_operando(CLASE_NORMAL, signo);
endfunction : gen_normal

// Function: gen_normal_banda
// Genera un operando normal en la banda segura de exponente
// [70, 184], con el signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_normal_banda(int signo);
	return gen_operando(CLASE_NORMAL_BANDA, signo);
endfunction : gen_normal_banda

// Function: gen_inf
// Genera un operando infinito (±Inf) con el signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_inf(int signo);
	return gen_operando(CLASE_INF, signo);
endfunction : gen_inf

// Function: gen_qnan
// Genera un operando qNaN con el signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_qnan(int signo);
	return gen_operando(CLASE_QNAN, signo);
endfunction : gen_qnan

// Function: gen_snan
// Genera un operando sNaN con el signo indicado.
function logic [C_FP_WIDTH-1:0] fpu_base_sequence_c::gen_snan(int signo);
	return gen_operando(CLASE_SNAN, signo);
endfunction : gen_snan