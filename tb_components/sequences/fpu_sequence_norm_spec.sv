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

// Task: body
// Familia deterministica: par (posicion, clase), recorriendo el cross
// completo posicion × clase cada C_NUM_POS_ESP items. Ver el detalle
// por posición en el encabezado del archivo.
task fpu_sequence_norm_spec_c::body();
	fpu_seq_item_c       item;
	fpu_posicion_esp_e   posicion;
	fpu_clase_operando_e clase;

	`uvm_info(get_type_name(),
		$sformatf("Inicio de secuencia norm_spec: %0d items", num_items_rand),
		UVM_MEDIUM)

	for (int i = 0; i < num_items_rand; i++) begin
		// familia deterministica: el cross posicion × clase se recorre
		// completo cada 12 items
		posicion = fpu_posicion_esp_e'(i % C_NUM_POS_ESP);
		clase    = C_CLASES_ESP[(i / C_NUM_POS_ESP) % C_NUM_CLASES_ESP];

		item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

		start_item(item);
            // operacion segun posicion; modo de redondeo aleatorio valido.
            // Con el especial en c, solo FMADD/FMSUB lo consumen (en las
            // demas operaciones el DUT ignora fp_c_i y el item degradaria
            // a arith_normal)
            if (posicion == POS_ESP_C) begin
                if (!item.randomize() with { op_code_i inside {FMADD, FMSUB}; })
                    `uvm_error(get_type_name(),
                        $sformatf("Fallo el randomize del item %0d", i))
            end
            else begin
                if (!item.randomize() with {
                        op_code_i inside {FADD, FSUB, FMUL, FMADD, FMSUB};
                    })
                    `uvm_error(get_type_name(),
                        $sformatf("Fallo el randomize del item %0d", i))
            end

            // un especial en la posicion de la familia; el resto en banda
            // segura (signo, payload y mantisas libres)
            case (posicion)
                POS_ESP_A : begin // especial contra b y c normales
                    item.fp_a_i = gen_operando(clase);
                    item.fp_b_i = gen_normal_banda();
                    item.fp_c_i = gen_normal_banda();
                end
                POS_ESP_B : begin // especial contra a y c normales
                    item.fp_a_i = gen_normal_banda();
                    item.fp_b_i = gen_operando(clase);
                    item.fp_c_i = gen_normal_banda();
                end
                POS_ESP_C : begin // producto finito (banda) + c especial
                    item.fp_a_i = gen_normal_banda();
                    item.fp_b_i = gen_normal_banda();
                    item.fp_c_i = gen_operando(clase);
                end
                // inalcanzable con i % 3; defensivo
                default : `uvm_error(get_type_name(),
                    $sformatf("Posicion de especial desconocida: %0d", posicion))
            endcase
		finish_item(item);

		`uvm_info(get_type_name(),
			$sformatf("Item %0d enviado: fam=(%s,%s) op=%s a=%8h b=%8h c=%8h rm=%s",
				i, posicion.name(), clase.name(), item.op_code_i.name(),
				item.fp_a_i, item.fp_b_i, item.fp_c_i, item.r_mode_i.name()),
			UVM_HIGH)
	end

	`uvm_info(get_type_name(), "Fin de secuencia norm_spec", UVM_MEDIUM)
endtask : body