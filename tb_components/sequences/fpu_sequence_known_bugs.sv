/*
 * File:    fpu_sequence_known_bugs.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test known_bugs (testplan sec. 2.2.6, test nuevo de
 *   TFG-##00): registro ejecutable de desviaciones documentadas del DUT.
 *   A diferencia de los demás tests, aquí NO hay generación por familias
 *   con campos libres: cada ítem es un vector byte-exacto, tomado del
 *   reporte.txt de Samuel o derivado a mano del RTL, que reproduce
 *   mínimamente un bug conocido. Por eso la secuencia recorre una tabla
 *   fija (índice i, sin aleatoriedad): un anclaje de regresión necesita
 *   entradas idénticas corrida a corrida.
 *
 *   Semántica por vector (el veredicto lo emite el scoreboard de tres
 *   cubetas num_pass / num_bug / num_fail; ver nota de dependencia abajo):
 *
 *     BUG-001 (flush de subnormal en fp_mul). El operando subnormal
 *       colapsa el producto a ±0. El golden calcula el valor IEEE real,
 *       así que hay discrepancia de RESULTADO (banderas coinciden en 0):
 *       es_bug_conocido() lo etiqueta -> num_bug. Tres vectores: en FMUL
 *       directo (patrón TC-125) y embebido en FMADD/FMSUB, para anclar
 *       que el bug afecta las tres operaciones.
 *
 *     BUG-003 (invalid_o = OR de result==qNaN | overflow | underflow).
 *       Un overflow puro fuerza invalid_o = 1, cosa que IEEE no hace (el
 *       desbordamiento activa OF y NX, no NV). El golden REPLICA esta
 *       derivación operativa, de modo que DUT y golden coinciden -> el
 *       vector cae en num_pass: confirma que el modelo reproduce la
 *       semántica de banderas del DUT (no la IEEE pura).
 *
 *     BUG-004 (las comparaciones fuerzan banderas a 0, aun con NaN).
 *       flt.s con qNaN e feq.s con sNaN señalarían NV en IEEE; el DUT
 *       fuerza invalid_o = 0. El golden también fuerza flags = 0 en
 *       comparaciones, así que estos vectores caen en num_pass y
 *       confirman la fidelidad de esa política.
 *
 *   BUG-002 (doble redondeo en FMADD/FMSUB) NO se ancla en línea: el
 *   golden lo replica con dos llamadas SoftFloat secuenciales, así que
 *   DUT == golden -> num_pass no revelaría nada. Su centinela vive en
 *   standalone_tests/driver/src/driver_directed.c, que FALLA si el
 *   modelo se cambiara a f32_mulAdd()/fmaf(). Aquí se documenta la
 *   exclusión, no se reproduce.
 *
 *   INVARIANTE del test: todo vector debe caer en num_pass o num_bug,
 *   nunca en num_fail. Un num_fail aquí significaría que el DUT cambió
 *   de forma (bug corregido o mutado) o que es_bug_conocido() no cubre
 *   el patrón — en ambos casos, señal de que hay que revisar. Los
 *   hallazgos nuevos de esta sesión (signo de inf en fp_flt, bit
 *   implícito del cero en fp_unpack, inf×subnormal y falsos positivos de
 *   underflow)
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

class fpu_sequence_known_bugs_c extends fpu_base_sequence_c;
	`uvm_object_utils(fpu_sequence_known_bugs_c)

	// identificador de bug, solo para el registro en el log
	typedef enum logic [2:0] {
		KB_BUG001 = 3'd0, // flush de subnormal en fp_mul
		KB_BUG003 = 3'd1, // invalid_o = OR de result/overflow/underflow
		KB_BUG004 = 3'd2  // banderas forzadas a 0 en comparaciones
	} kb_bug_id_e;

	// un vector canonico: operacion, modo, bug asociado y los tres operandos
	typedef struct packed {
		fpu_op_code_e          op;
		fpu_r_mode_e           rm;
		kb_bug_id_e            bug;
		logic [C_FP_WIDTH-1:0] a;
		logic [C_FP_WIDTH-1:0] b;
		logic [C_FP_WIDTH-1:0] c;
	} kb_vector_t;

	localparam int C_NUM_VEC_BUG = 6;

	// Tabla de anclaje. Orden de campos: op, rm, bug, a, b, c.
	//   0 BUG-001 TC-125 : 2^-149 × 10.0   -> DUT 0x00000000, golden 0x0000000A
	//   1 BUG-001 FMADD  : (2^-149 × 10) + 0 -> DUT 0, golden 0x0000000A
	//   2 BUG-001 FMSUB  : (2^-149 × 10) - 0 -> DUT 0, golden 0x0000000A
	//   3 BUG-003 ovf    : 2^127 × 2^127    -> +inf, invalid=1 (DUT y golden)
	//   4 BUG-004 flt    : qNaN < 1.0       -> cmp 0, invalid 0 (IEEE daria NV)
	//   5 BUG-004 feq    : sNaN == 1.0      -> cmp 0, invalid 0 (IEEE daria NV)
	localparam kb_vector_t C_VECTORES[C_NUM_VEC_BUG] = '{
		'{FMUL,  RMM, KB_BUG001, 32'h00000001, 32'h41200000, 32'h00000000},
		'{FMADD, RNE, KB_BUG001, 32'h00000001, 32'h41200000, 32'h00000000},
		'{FMSUB, RNE, KB_BUG001, 32'h00000001, 32'h41200000, 32'h00000000},
		'{FMUL,  RNE, KB_BUG003, 32'h7F000000, 32'h7F000000, 32'h00000000},
		'{FLT,   RNE, KB_BUG004, 32'h7FC00000, 32'h3F800000, 32'h00000000},
		'{FEQ,   RNE, KB_BUG004, 32'h7FA00000, 32'h3F800000, 32'h00000000}
	};

	// recorrido exacto de la tabla, sin repeticion: el == sobreescribe el
	// soft [100:200] de la base (una pasada basta; los vectores son fijos)
	constraint cn_num_items_bug {
		num_items_rand == C_NUM_VEC_BUG;
	}

	// Prototipos de funciones de la secuencia
	extern function new(string name = "fpu_sequence_known_bugs_c");
	extern virtual task body();

endclass : fpu_sequence_known_bugs_c

function fpu_sequence_known_bugs_c::new(string name = "fpu_sequence_known_bugs_c");
	super.new(name);
endfunction : new

// Task: body
// Recorrido exacto (sin aleatoriedad) de C_VECTORES: cada item fija
// sus cinco campos directamente desde la tabla de anclaje, sin
// randomize. Ver semántica por vector en el encabezado del archivo.
task fpu_sequence_known_bugs_c::body();
	fpu_seq_item_c item;
	kb_vector_t    vec;

	`uvm_info(get_type_name(),
		$sformatf("Inicio de secuencia known_bugs: %0d vectores", num_items_rand),
		UVM_MEDIUM)
endtask : body