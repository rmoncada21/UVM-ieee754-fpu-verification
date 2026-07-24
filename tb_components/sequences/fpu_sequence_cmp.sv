/*
 * File:    fpu_sequence_cmp.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test cmp (testplan sec. 2.2.4, test nuevo de TFG-##00):
 *   valida cmp_result_o en FEQ/FLT/FLE. El testplan pide el cruce
 *   {FEQ, FLT, FLE} × {normal, ±0, ±inf, qNaN, sNaN}; aquí se agrega
 *   CLASE_SUBNORMAL al cruce porque el orden entre ±0 y un subnormal es
 *   una rama propia del RTL (ambos con exponente 0, decidida por la
 *   comparación de mantisas) que ninguna otra clase ejercita.
 *
 *   Familia del item i: op = i mod 3, escenario = (i / 3) mod 5. La
 *   vuelta v = i / 15 es el sub-índice de cada escenario, así que los
 *   tres items de un escenario dentro de una vuelta comparten estímulo
 *   y recorren las tres operaciones (cruce op × escenario completo):
 *     CMP_CROSS     : par (clase_a, clase_b) = (v, v/6) mod 6 — cierra
 *       las 36 parejas × 3 ops en 36 vueltas; es el escenario más lento
 *       y por eso fija el periodo.
 *     CMP_IGUAL     : b = a (patrón idéntico), clase = v mod 6, signo =
 *       (v / 6) mod 2. Única vía a FEQ = 1 con normales: con operandos
 *       independientes la igualdad ocurre con probabilidad ~2^-32. Con
 *       clase NaN comprueba que NaN != NaN pese al patrón idéntico.
 *     CMP_OPUESTO   : b = a con el bit de signo invertido. Cubre
 *       +0 vs -0 (FEQ = 1), ±x, y los dos infinitos de signo opuesto.
 *     CMP_ADYACENTE : a normal (rango completo), b = a ± 1 en patrón de
 *       bits: mismo exponente salvo en el borde, así que la decisión
 *       cae en la comparación de mantisas — rama que dos operandos
 *       independientes casi nunca alcanzan (P[exp_a == exp_b] ≈ 1/254).
 *     CMP_CERO_SUB  : ±0 contra un subnormal del mismo signo, en ambos
 *       órdenes (orden = v mod 2, signo = (v / 2) mod 2).
 *
 *   r_mode_i y fp_c_i quedan aleatorios a propósito: el DUT no los
 *   consume en comparaciones (gating de fp_alu) y la comparación contra
 *   el golden verifica esa independencia. Las banderas no se estimulan:
 *   el DUT fuerza invalid_o = 0 en comparaciones (BUG-004) y el modelo
 *   de referencia replica esa semántica, de modo que los casos con NaN
 *   se documentan como desviación, no como falla.
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

 class fpu_sequence_cmp_c extends fpu_base_sequence_c;
	`uvm_object_utils(fpu_sequence_cmp_c)

	// operaciones de comparacion, indexables para el recorrido determinista
	localparam int C_NUM_OPS_CMP = 3;
	protected fpu_op_code_e ops_cmp[C_NUM_OPS_CMP] = '{FEQ, FLT, FLE};

	// mascara del bit de signo binary32 (escenario CMP_OPUESTO)
	localparam logic [C_FP_WIDTH-1:0] C_MASCARA_SIGNO = 32'h8000_0000;

	// una vuelta emite las 3 operaciones × los 5 escenarios
	localparam int C_ITEMS_VUELTA = C_NUM_OPS_CMP * C_NUM_ESC_CMP;
	// vueltas necesarias para cerrar el escenario mas lento (CMP_CROSS)
	localparam int C_VUELTAS_CMP  = C_NUM_CLASES_CMP * C_NUM_CLASES_CMP;
	localparam int C_PERIODO_CMP  = C_ITEMS_VUELTA * C_VUELTAS_CMP;

	// Rango DURO, no solo piso: el periodo de este test (540) excede el
	// soft [100:200] de la base, que el solver descarta por contradiccion.
	// Un piso sin techo dejaria num_items_rand sin cota superior (int
	// aleatorio), asi que aqui se fija el intervalo completo.
	constraint cn_num_items_cmp {
		num_items_rand inside {[C_PERIODO_CMP : 2 * C_PERIODO_CMP]};
	}

	// Prototipos de funciones de la secuencia
	extern function new(string name = "fpu_sequence_cmp_c");
	extern virtual task body();

endclass : fpu_sequence_cmp_c

function fpu_sequence_cmp_c::new(string name = "fpu_sequence_cmp_c");
	super.new(name);
endfunction : new

// Task: body
// Recorrido determinista {FEQ, FLT, FLE} × 5 escenarios (CMP_CROSS,
// CMP_IGUAL, CMP_OPUESTO, CMP_ADYACENTE, CMP_CERO_SUB); ver el
// desglose de cada escenario en el encabezado del archivo.
task fpu_sequence_cmp_c::body();
	fpu_seq_item_c       item;
	fpu_op_code_e        op_fam;
	fpu_escenario_cmp_e  escenario;
	fpu_clase_operando_e clase_a;
	fpu_clase_operando_e clase_b;
	fpu_clase_operando_e clase;
	int                  vuelta;
	int                  signo;

	`uvm_info(get_type_name(),
		$sformatf("Inicio de secuencia cmp: %0d items", num_items_rand),
		UVM_MEDIUM)

	for (int i = 0; i < num_items_rand; i++) begin
		// familia deterministica: operacion y escenario; la vuelta es el
		// sub-indice interno de cada escenario
		op_fam    = ops_cmp[i % C_NUM_OPS_CMP];
		escenario = fpu_escenario_cmp_e'((i / C_NUM_OPS_CMP) % C_NUM_ESC_CMP);
		vuelta    = i / C_ITEMS_VUELTA;

		item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

		start_item(item);
            // operacion fijada por la familia; r_mode_i y fp_c_i quedan
            // aleatorios: el DUT los ignora en comparaciones
            if (!item.randomize() with { op_code_i == op_fam; })
                `uvm_error(get_type_name(),
                    $sformatf("Fallo el randomize del item %0d", i))

            case (escenario)
                // cross determinista clase_a × clase_b (36 parejas)
                CMP_CROSS : begin
                    clase_a = C_CLASES_CMP[vuelta % C_NUM_CLASES_CMP];
                    clase_b = C_CLASES_CMP[(vuelta / C_NUM_CLASES_CMP)
                                        % C_NUM_CLASES_CMP];
                    item.fp_a_i = gen_operando(clase_a);
                    item.fp_b_i = gen_operando(clase_b);
                end
                // patron identico: FEQ = 1 (salvo NaN), FLT = 0, FLE = 1
                CMP_IGUAL : begin
                    clase = C_CLASES_CMP[vuelta % C_NUM_CLASES_CMP];
                    signo = (vuelta / C_NUM_CLASES_CMP) % 2;
                    item.fp_a_i = gen_operando(clase, signo);
                    item.fp_b_i = item.fp_a_i;
                end
                // misma magnitud, signo opuesto: ±0, ±x, ±inf
                CMP_OPUESTO : begin
                    clase = C_CLASES_CMP[vuelta % C_NUM_CLASES_CMP];
                    signo = (vuelta / C_NUM_CLASES_CMP) % 2;
                    item.fp_a_i = gen_operando(clase, signo);
                    item.fp_b_i = item.fp_a_i ^ C_MASCARA_SIGNO;
                end
                // vecino a ±1 ULP: la decision cae en la mantisa
                CMP_ADYACENTE : begin
                    item.fp_a_i = gen_normal();
                    item.fp_b_i = ((vuelta % 2) == 0) ? (item.fp_a_i + 32'd1)
                                                    : (item.fp_a_i - 32'd1);
                end
                // ±0 contra subnormal del mismo signo, en ambos ordenes
                CMP_CERO_SUB : begin
                    signo = (vuelta / 2) % 2;
                    if ((vuelta % 2) == 0) begin
                        item.fp_a_i = gen_cero(signo);
                        item.fp_b_i = gen_subnormal(signo);
                    end
                    else begin
                        item.fp_a_i = gen_subnormal(signo);
                        item.fp_b_i = gen_cero(signo);
                    end
                end
                // inalcanzable con % C_NUM_ESC_CMP; defensivo
                default : `uvm_error(get_type_name(),
                    $sformatf("Escenario de comparacion desconocido: %0d", escenario))
            endcase
		finish_item(item);

		`uvm_info(get_type_name(),
			$sformatf("Item %0d enviado: fam=%s vuelta=%0d op=%s a=%8h b=%8h",
				i, escenario.name(), vuelta, item.op_code_i.name(),
				item.fp_a_i, item.fp_b_i),
			UVM_HIGH)
	end
	`uvm_info(get_type_name(), "Fin de secuencia cmp", UVM_MEDIUM)

endtask : body
