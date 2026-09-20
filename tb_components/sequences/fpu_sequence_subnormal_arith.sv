/*
 * File:    fpu_sequence_subnormal_arith.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test subnormal_arith (testplan sec. 2.2.5, test nuevo de
 *   TFG-##00): aritmética dirigida con subnormales. Es el test que convierte
 *   BUG-001 en observable y el que absorbe los subnormales que special_spec y
 *   norm_spec dejaron fuera por diseño.
 *
 *   Familia del item i: i mod 6; la vuelta v = i / 6 es el sub-índice interno.
 *   Todo el estímulo es dirigido (el testplan lo exige explícitamente); solo
 *   quedan libres mantisas, signos y los operandos que el DUT ignora.
 *
 *     SUB_MUL_NORM   : FMUL con a subnormal y b normal. Tres variantes de b
 *       (v mod 3): +1.0 exacto (producto = a, subnormal exacto), normal de
 *       exponente C_EXP_MUL_ALTO (producto NORMAL garantizado: el DUT lo
 *       aplana a cero sin levantar bandera, patrón TC-125) y normal libre.
 *     SUB_MADD_NORM  : el mismo patrón dentro de FMADD/FMSUB (v mod 2), con
 *       b de exponente alto para que el producto sea normal y c en dos
 *       variantes: ±0 (el resultado esperado es el producto entero, así que
 *       el flush queda desnudo) y normal en banda.
 *     SUB_UDF_INEXAC : FMUL de dos normales de mantisa impar cuyos exponentes
 *       suman entre 105 y 127: el producto cae en rango subnormal con pérdida
 *       -> underflow gradual real (UF ∧ NX). Mantisas impares: la inexactitud
 *       queda garantizada, no librada al azar.
 *     SUB_UDF_EXACTO : FMUL de dos potencias de dos con la misma suma de
 *       exponentes, extendida hasta 128: el producto es un subnormal EXACTO
 *       (UF debe ser 0: tiny sin pérdida) y, en la suma 128, el normal mínimo
 *       exacto — control positivo que el DUT debe aprobar.
 *     SUB_INF        : FMUL de inf contra subnormal en ambos órdenes y con
 *       las cuatro combinaciones de signo.
 *     SUB_SUMA       : subnormales en el sumador (v mod 4): sub + sub, sub -
 *       sub, normal mínimo menos su vecino inferior (da el subnormal mínimo
 *       exacto: underflow gradual del sumador) y sub + normal en banda como
 *       control de resultado normal inexacto.
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

class fpu_sequence_subnormal_arith_c extends fpu_base_sequence_c;
	`uvm_object_utils(fpu_sequence_subnormal_arith_c)

	// la familia mas lenta es SUB_UDF_EXACTO: recorre las sumas de exponente
	// de C_EXP_SUMA_SUB_MIN a C_EXP_SUMA_NORM_MIN (24 valores)
	localparam int C_VUELTAS_SUB = C_EXP_SUMA_NORM_MIN - C_EXP_SUMA_SUB_MIN + 1;
	localparam int C_PERIODO_SUB = C_NUM_FAM_SUB * C_VUELTAS_SUB;

	// piso duro: una pasada completa de las 6 familias × 24 vueltas = 144.
	// Cae dentro del soft [100:200] de la base, que sigue acotando arriba.
	constraint cn_num_items_minimo {
		num_items_rand >= C_PERIODO_SUB;
	}

	// Prototipos de funciones de la secuencia
	extern function new(string name = "fpu_sequence_subnormal_arith_c");
	extern virtual task body();

endclass : fpu_sequence_subnormal_arith_c


function fpu_sequence_subnormal_arith_c::new(string name = "fpu_sequence_subnormal_arith_c");
	super.new(name);
endfunction : new

// Task: body
// Familia deterministica i mod 6 (SUB_MUL_NORM, SUB_MADD_NORM,
// SUB_UDF_INEXAC, SUB_UDF_EXACTO, SUB_INF, SUB_SUMA); la vuelta
// v = i / 6 indexa las variantes internas de cada familia. Ver el
// desglose completo de cada una en el encabezado del archivo.
task fpu_sequence_subnormal_arith_c::body();
	fpu_seq_item_c         item;
	fpu_familia_sub_e      familia_sub;
	fpu_op_code_e          op_fam;
	int                    vuelta;
	int                    suma_exp;
	int                    exp_a;
	int                    exp_b;
	int                    signo;
	logic [C_FP_WIDTH-1:0] op_base;

	`uvm_info(get_type_name(),
		$sformatf("Inicio de secuencia subnormal_arith: %0d items", num_items_rand),
		UVM_MEDIUM)

	for (int i = 0; i < num_items_rand; i++) begin
		// familia deterministica; la vuelta indexa las variantes internas
		familia_sub = fpu_familia_sub_e'(i % C_NUM_FAM_SUB);
		vuelta      = i / C_NUM_FAM_SUB;

		item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

		start_item(item);
            case (familia_sub)
                // -------- FMUL: subnormal × normal (patron BUG-001) --------
                SUB_MUL_NORM : begin
                    if (!item.randomize() with { op_code_i == FMUL; })
                        `uvm_error(get_type_name(),
                            $sformatf("Fallo el randomize del item %0d", i))
                    signo       = (vuelta / 3) % 2;
                    item.fp_a_i = gen_subnormal(signo);
                    case (vuelta % 3)
                        // b = +1.0: el producto es el propio subnormal, exacto
                        0 : item.fp_b_i = gen_operando(CLASE_POTENCIA_DOS, 0,
                                                    C_EXP_SESGO);
                        // b alto: el producto es normal; el DUT devuelve cero
                        // sin bandera alguna (patron TC-125)
                        1 : item.fp_b_i = gen_operando(CLASE_NORMAL, -1,
                                                    C_EXP_MUL_ALTO);
                        // b libre: exploracion del rango completo
                        default : item.fp_b_i = gen_normal();
                    endcase
                    // fp_c_i queda aleatorio: el DUT no lo consume en FMUL
                end
                // -------- FMADD/FMSUB: el patron embebido --------
                SUB_MADD_NORM : begin
                    op_fam = ((vuelta % 2) == 0) ? FMADD : FMSUB;
                    if (!item.randomize() with { op_code_i == op_fam; })
                        `uvm_error(get_type_name(),
                            $sformatf("Fallo el randomize del item %0d", i))
                    signo       = (vuelta / 4) % 2;
                    item.fp_a_i = gen_subnormal(signo);
                    item.fp_b_i = gen_operando(CLASE_NORMAL, -1, C_EXP_MUL_ALTO);
                    // c = ±0 deja el resultado esperado igual al producto:
                    // el flush del multiplicador queda desnudo
                    if (((vuelta / 2) % 2) == 0)
                        item.fp_c_i = gen_cero();
                    else
                        item.fp_c_i = gen_normal_banda();
                end
                // -------- FMUL: producto subnormal INEXACTO (UF real) --------
                SUB_UDF_INEXAC : begin
                    if (!item.randomize() with { op_code_i == FMUL; })
                        `uvm_error(get_type_name(),
                            $sformatf("Fallo el randomize del item %0d", i))
                    suma_exp = C_EXP_SUMA_SUB_MIN + (vuelta % C_NUM_SUMA_SUB);
                    exp_a    = suma_exp / 2;
                    exp_b    = suma_exp - exp_a;
                    item.fp_a_i = gen_operando(CLASE_NORMAL_IMPAR, -1, exp_a);
                    item.fp_b_i = gen_operando(CLASE_NORMAL_IMPAR, -1, exp_b);
                end
                // -------- FMUL: producto subnormal EXACTO (UF debe ser 0) ----
                SUB_UDF_EXACTO : begin
                    if (!item.randomize() with { op_code_i == FMUL; })
                        `uvm_error(get_type_name(),
                            $sformatf("Fallo el randomize del item %0d", i))
                    suma_exp = C_EXP_SUMA_SUB_MIN + (vuelta % C_VUELTAS_SUB);
                    exp_a    = suma_exp / 2;
                    exp_b    = suma_exp - exp_a;
                    item.fp_a_i = gen_operando(CLASE_POTENCIA_DOS, -1, exp_a);
                    item.fp_b_i = gen_operando(CLASE_POTENCIA_DOS, -1, exp_b);
                end
                // -------- FMUL: inf × subnormal --------
                SUB_INF : begin
                    if (!item.randomize() with { op_code_i == FMUL; })
                        `uvm_error(get_type_name(),
                            $sformatf("Fallo el randomize del item %0d", i))
                    signo = (vuelta / 4) % 2; // signo del subnormal
                    if ((vuelta % 2) == 0) begin
                        item.fp_a_i = gen_inf((vuelta / 2) % 2);
                        item.fp_b_i = gen_subnormal(signo);
                    end
                    else begin
                        item.fp_a_i = gen_subnormal(signo);
                        item.fp_b_i = gen_inf((vuelta / 2) % 2);
                    end
                end
                // -------- FADD/FSUB: subnormales en el sumador --------
                SUB_SUMA : begin
                    case (vuelta % 4)
                        0, 3    : op_fam = FADD;
                        default : op_fam = FSUB;
                    endcase
                    if (!item.randomize() with { op_code_i == op_fam; })
                        `uvm_error(get_type_name(),
                            $sformatf("Fallo el randomize del item %0d", i))
                    signo = (vuelta / 4) % 2;
                    case (vuelta % 4)
                        // suma y resta exactas de subnormales del mismo signo
                        0, 1 : begin
                            item.fp_a_i = gen_subnormal(signo);
                            item.fp_b_i = gen_subnormal(signo);
                        end
                        // normal minimo menos su vecino inferior: el resultado
                        // es el subnormal minimo, exacto (underflow gradual)
                        2 : begin
                            op_base     = gen_operando(CLASE_NORMAL, signo,
                                                    C_EXP_MIN_NORMAL);
                            item.fp_a_i = op_base;
                            item.fp_b_i = op_base - 32'd1;
                        end
                        // control: resultado normal, subnormal absorbido (NX)
                        default : begin
                            item.fp_a_i = gen_subnormal(signo);
                            item.fp_b_i = gen_normal_banda();
                        end
                    endcase
                end
                // inalcanzable con % C_NUM_FAM_SUB; defensivo
                default : `uvm_error(get_type_name(),
                    $sformatf("Familia de subnormales desconocida: %0d", familia_sub))
            endcase

		finish_item(item);

		`uvm_info(get_type_name(),
			$sformatf("Item %0d enviado: familia_sub=%s vuelta=%0d op=%s a=%8h b=%8h c=%8h rm=%s",
				i, familia_sub.name(), vuelta, item.op_code_i.name(), item.fp_a_i,
				item.fp_b_i, item.fp_c_i, item.r_mode_i.name()),
			UVM_HIGH)
	end

	`uvm_info(get_type_name(), "Fin de secuencia subnormal_arith", UVM_MEDIUM)
endtask : body