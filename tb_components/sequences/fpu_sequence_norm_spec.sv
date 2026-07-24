/*
 * File:    fpu_sequence_norm_spec.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test norm_spec (testplan sec. 2.2.2): exactamente un
 *   operando especial (±0, ±inf, qNaN, sNaN) contra operandos normales
 *   en banda segura [70, 184]. La familia del item i se deriva
 *   determinísticamente como el par (posición, clase):
 *     posicion = i mod C_NUM_POS_ESP
 *     clase    = C_CLASES_ESP[(i / C_NUM_POS_ESP) mod C_NUM_CLASES_ESP]
 *   Cada bloque de 12 items cubre exactamente una vez el cross completo
 *   posición × clase. Con el especial en a o b, la clase entra por la
 *   etapa de multiplicación/operandos (0×normal, inf±normal, NaN
 *   entrante); con el especial en c (solo FMADD/FMSUB), el producto
 *   finito de dos normales en banda se encuentra con el especial en la
 *   etapa de suma del FMA — el caso "producto finito, c especial"
 *   asignado a este test. Los operandos no especiales van en banda
 *   segura para que el resultado quede determinado solo por la
 *   semántica del especial: sin overflow/underflow accidental (dominio
 *   de flag_arith), sin el caso pendiente TFG-##22 (producto intermedio
 *   tiny) y sin interferir con BUG-001 (no hay subnormales: van a su
 *   test dedicado). La aleatoriedad queda dentro de la familia:
 *   operación, modo de redondeo, signos, payloads de NaN y mantisas;
 *   el esperado lo resuelve el modelo de referencia. Comparaciones con
 *   especiales: fuera de alcance, van al test de comparación.
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

 class fpu_sequence_norm_spec_c extends fpu_base_sequence_c;
    `uvm_objects_utils(fpu_sequence_norm_spec_c)
    // piso duro: una pasada completa del cross posicion × clase = 12
	// familias. Convive con el soft [100:200] de la base; si alguien lo
	// baja de 12 a proposito, el randomize falla ruidosamente en vez de
	// degradar la cobertura en silencio.
	constraint cn_num_items_minimo {
		num_items_rand >= C_NUM_POS_ESP * C_NUM_CLASES_ESP;
	}

    // Prototipos de funciones de la secuencia
	extern function new(string name = "fpu_sequence_norm_spec_c");
	extern virtual task body();
 endclass : fpu_sequence_norm_spec_c

function fpu_sequence_norm_spec_c::new(string name = "fpu_sequence_norm_spec_c");
	super.new(name);
endfunction : new