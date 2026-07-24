/*
 * File:    fpu_sequence_special_spec.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test special_spec (testplan sec. 2.2.2): operandos
 *   especiales (±0, ±inf, qNaN, sNaN) en las cinco operaciones
 *   aritméticas, incluyendo la propagación de NaN. La familia del item
 *   i se deriva determinísticamente como los tres dígitos en base 4 del
 *   índice sobre C_CLASES_ESP:
 *     (clase_a, clase_b, clase_c) = (i, i/4, i/16) mod C_NUM_CLASES_ESP
 *   Cada bloque de 16 items cubre exactamente una vez los 16 pares
 *   (a, b); con num_items_rand >= 64 el cross completo (a, b, c) queda
 *   cubierto al menos una vez. La aleatoriedad queda dentro de la
 *   familia: operación, modo de redondeo, signos y payloads de NaN;
 *   ambas polaridades de cada par (p. ej. inf+inf e inf−inf, con su
 *   invalid en la etapa de suma del FMA) emergen del muestreo y el
 *   esperado lo resuelve el modelo de referencia. Para FADD/FSUB/FMUL
 *   el DUT ignora fp_c_i: conducir también ahí un especial verifica de
 *   paso esa independencia (cualquier consumo indebido divergiría del
 *   golden). Comparaciones con especiales: fuera de alcance, van al
 *   test de comparación.
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

class fpu_sequence_special_spec_c extends fpu_base_sequence_c;
	`uvm_object_utils(fpu_sequence_special_spec_c)

	// una pasada completa del cross (a, b, c) = 4^3 familias.
	// Convive con el soft [100:200] de la base; 
    // si se baja de 64 a proposito, el randomize falla, en vez de degradar la
	// cobertura en silencio.
	constraint cn_num_items_minimo {
		num_items_rand >= C_NUM_CLASES_ESP * C_NUM_CLASES_ESP * C_NUM_CLASES_ESP;
	}

	// Prototipos de funciones de la secuencia
	extern function new(string name = "fpu_sequence_special_spec_c");
	extern virtual task body();

endclass : fpu_sequence_special_spec_c