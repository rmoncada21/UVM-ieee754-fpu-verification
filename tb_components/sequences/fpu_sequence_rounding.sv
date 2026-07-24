/*
 * File:    fpu_sequence_rounding.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test rounding (testplan sec. 2.2.3, versión mejorada:
 *   cross operación × modo en vez de modo aislado). La familia del item
 *   i se deriva determinísticamente como la terna (op, modo, tipo):
 *     op   = ops_arit[i mod 5]
 *     modo = modos_redondeo[(i / 5) mod 5]
 *     tipo = (i / 25) mod C_NUM_EST_RED
 *   con periodo 50: cada bloque de 50 items cubre exacto el cross.
 *   Tipos de estímulo:
 *     RED_ALEATORIO: tres operandos en banda segura; el resultado es
 *       inexacto casi siempre, distingue RTZ/RDN/RUP entre sí (y de
 *       RNE) y ejercita el doble redondeo de FMADD/FMSUB bajo cada
 *       modo de usuario (BUG-002: el golden lo replica).
 *     RED_EMPATE: empate exacto garantizado (guard = 1, sticky = 0),
 *       único estímulo donde RNE y RMM difieren — sin él la columna
 *       RMM del cross sería vacua (un empate aleatorio ocurre con
 *       probabilidad ~2^-24). Construcción por operación:
 *         FADD/FSUB: a banda; b = ±medio ULP de a (potencia de dos con
 *           exp(a) - 24); suma o resta efectiva, ambas empatan.
 *         FMUL: a con mantisa impar acotada × (+1.5): el único bit
 *           descartado tras normalizar es 1 (ver cn_normal_empate_mul).
 *         FMADD/FMSUB: a = ±1.0 (producto = ±b exacto, la primera
 *           etapa RNE no redondea) y c = ±medio ULP del producto: el
 *           empate cae solo en la segunda etapa, que redondea con el
 *           modo de usuario.
 *   La banda segura mantiene todo normal: la saturación por modo en
 *   overflow/underflow ya la cubre flag_arith, y no hay subnormales
 *   (BUG-001 fuera) ni el caso pendiente TFG-##22. La aleatoriedad
 *   queda dentro de la familia: signos, mantisas y payloads; el
 *   esperado por modo lo resuelve el modelo de referencia.
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

class fpu_sequence_rounding_c extends fpu_base_sequence_c;
	`uvm_object_utils(fpu_sequence_rounding_c)

	// tamano y listas indexables del recorrido determinista del cross
	localparam int C_NUM_OPS_ARIT = 5;
	localparam int C_NUM_R_MODES  = 5;
	protected fpu_op_code_e ops_arit[C_NUM_OPS_ARIT] =
		'{FADD, FSUB, FMUL, FMADD, FMSUB};
	protected fpu_r_mode_e modos_redondeo[C_NUM_R_MODES] =
		'{RNE, RTZ, RDN, RUP, RMM};

	// +1.5 exacto: segundo operando del empate dirigido de FMUL (el
	// signo aleatorio del par ya lo porta el operando a)
	localparam logic [C_FP_WIDTH-1:0] C_FP_UNO_Y_MEDIO = 32'h3FC00000;

	// piso duro: una pasada completa del cross op × modo × tipo = 50
	// familias. Convive con el soft [100:200] de la base; si alguien lo
	// baja de 50 a proposito, el randomize falla ruidosamente en vez de
	// degradar la cobertura en silencio.
	constraint cn_num_items_minimo {
		num_items_rand >= C_NUM_OPS_ARIT * C_NUM_R_MODES * C_NUM_EST_RED;
	}

	// Prototipos de funciones de la secuencia
	extern function new(string name = "fpu_sequence_rounding_c");
	extern protected function int exponente_de(logic [C_FP_WIDTH-1:0] operando);
	extern virtual task body();

endclass : fpu_sequence_rounding_c