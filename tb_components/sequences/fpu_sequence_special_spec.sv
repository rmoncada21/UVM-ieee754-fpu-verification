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


function fpu_sequence_special_spec_c::new(string name = "fpu_sequence_special_spec_c");
	super.new(name);
endfunction : new

// Task: body
// Familia deterministica: digitos en base 4 del indice (clase_a,
// clase_b, clase_c) sobre C_CLASES_ESP, recorriendo el cross completo
// de pares (a, b) cada 16 items.
task fpu_sequence_special_spec_c::body();
	fpu_seq_item_c       item;
	fpu_clase_operando_e clase_a;
	fpu_clase_operando_e clase_b;
	fpu_clase_operando_e clase_c;

	`uvm_info(get_type_name(),
		$sformatf("Inicio de secuencia special_spec: %0d items", num_items_rand),
		UVM_MEDIUM)

	for (int i = 0; i < num_items_rand; i++) begin
		// familia deterministica: digitos en base 4 del indice; el cross
		// completo de clases especiales se recorre cada 64 items
		clase_a = C_CLASES_ESP[i % C_NUM_CLASES_ESP];
		clase_b = C_CLASES_ESP[(i / C_NUM_CLASES_ESP) % C_NUM_CLASES_ESP];
		clase_c = C_CLASES_ESP[(i / (C_NUM_CLASES_ESP * C_NUM_CLASES_ESP))
			% C_NUM_CLASES_ESP];

		item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

		start_item(item);
			// operacion aritmetica y modo de redondeo valido, aleatorios
			if (!item.randomize() with {
					op_code_i inside {FADD, FSUB, FMUL, FMADD, FMSUB};
				})
				`uvm_error(get_type_name(),
					$sformatf("Fallo el randomize del item %0d", i))
			// operandos especiales de la familia; signo y payload libres
			item.fp_a_i = gen_operando(clase_a);
			item.fp_b_i = gen_operando(clase_b);
			item.fp_c_i = gen_operando(clase_c);
		finish_item(item);

		`uvm_info(get_type_name(),
			$sformatf("Item %0d enviado: fam=(%s,%s,%s) op=%s a=%8h b=%8h c=%8h rm=%s",
				i, clase_a.name(), clase_b.name(), clase_c.name(),
				item.op_code_i.name(), item.fp_a_i, item.fp_b_i,
				item.fp_c_i, item.r_mode_i.name()),
			UVM_HIGH)
	end

	`uvm_info(get_type_name(), "Fin de secuencia special_spec", UVM_MEDIUM)
endtask : body