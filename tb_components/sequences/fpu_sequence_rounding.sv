/*
 * File:    fpu_sequence_rounding.sv
 * - Project:  FPU RV32F  Verificación funcional UVM
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
 *       único estímulo donde RNE y RMM difieren  sin él la columna
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

	// pasada completa del cross op × modo × tipo = 50
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


function fpu_sequence_rounding_c::new(string name = "fpu_sequence_rounding_c");
	super.new(name);
endfunction : new

// Function: exponente_de
// extrae el campo exponente (sesgado) de un operando binary32
function int fpu_sequence_rounding_c:(logic [C_FP_WIDTH-1:0] operando);
	return int'(operando[C_FP_WIDTH-2 -: C_EXP_WIDTH]);
endfunction : exponente_de

// Task: body
// Familia deterministica: terna (op, modo, tipo), recorriendo el
// cross completo cada 50 items. Ver el detalle de RED_ALEATORIO y
// RED_EMPATE en el encabezado del archivo.
task fpu_sequence_rounding_c::body();
	fpu_seq_item_c         item;
	fpu_op_code_e          op_fam;
	fpu_r_mode_e           modo_fam;
	fpu_estimulo_red_e     tipo;
	logic [C_FP_WIDTH-1:0] op_base;

	`uvm_info(get_type_name(),
		$sformatf("Inicio de secuencia rounding: %0d items", num_items_rand),
		UVM_MEDIUM)

	for (int i = 0; i < num_items_rand; i++) begin
		// familia deterministica: el cross op × modo × tipo se recorre
		// completo cada 50 items
		op_fam   = ops_arit[i % C_NUM_OPS_ARIT];
		modo_fam = modos_redondeo[(i / C_NUM_OPS_ARIT) % C_NUM_R_MODES];
		tipo     = fpu_estimulo_red_e'(
			(i / (C_NUM_OPS_ARIT * C_NUM_R_MODES)) % C_NUM_EST_RED);

		item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

		start_item(item);
            // operacion y modo de redondeo fijados por la familia
            if (!item.randomize() with {
                    op_code_i == op_fam;
                    r_mode_i  == modo_fam;
                })
                `uvm_error(get_type_name(),
                    $sformatf("Fallo el randomize del item %0d", i))

            case (tipo)
                // operandos banda aleatorios: inexacto generico
                RED_ALEATORIO : begin
                    item.fp_a_i = gen_normal_banda();
                    item.fp_b_i = gen_normal_banda();
                    item.fp_c_i = gen_normal_banda();
                end
                // empate exacto garantizado (guard = 1, sticky = 0)
                RED_EMPATE : begin
                    case (op_fam)
                        FADD, FSUB : begin
                            // b = ±medio ULP de a: potencia de dos con
                            // exponente exp(a) - (mantisa + 1)
                            op_base     = gen_normal_banda();
                            item.fp_a_i = op_base;
                            item.fp_b_i = gen_operando(CLASE_POTENCIA_DOS, -1,
                                exponente_de(op_base) - (C_MANT_WIDTH + 1));
                            item.fp_c_i = gen_normal_banda();
                        end
                        FMUL : begin
                            // mantisa impar acotada × (+1.5): un solo bit
                            // descartado, igual a 1
                            item.fp_a_i = gen_operando(CLASE_NORMAL_EMPATE_MUL);
                            item.fp_b_i = C_FP_UNO_Y_MEDIO;
                            item.fp_c_i = gen_normal_banda();
                        end
                        // FMADD, FMSUB: a = ±1.0 -> producto = ±b exacto;
                        // c = ±medio ULP del producto -> el empate cae solo
                        // en la segunda etapa (modo de usuario)
                        default : begin
                            item.fp_a_i = gen_operando(CLASE_POTENCIA_DOS, -1,
                                C_EXP_SESGO);
                            op_base     = gen_normal_banda();
                            item.fp_b_i = op_base;
                            item.fp_c_i = gen_operando(CLASE_POTENCIA_DOS, -1,
                                exponente_de(op_base) - (C_MANT_WIDTH + 1));
                        end
                    endcase
                end
                // inalcanzable con % C_NUM_EST_RED; defensivo
                default : `uvm_error(get_type_name(),
                    $sformatf("Tipo de estimulo desconocido: %0d", tipo))
            endcase
		finish_item(item);

		`uvm_info(get_type_name(),
			$sformatf("Item %0d enviado: fam=%s op=%s a=%8h b=%8h c=%8h rm=%s",
				i, tipo.name(), item.op_code_i.name(), item.fp_a_i,
				item.fp_b_i, item.fp_c_i, item.r_mode_i.name()),
			UVM_HIGH)
	end
	`uvm_info(get_type_name(), "Fin de secuencia rounding", UVM_MEDIUM)
endtask : body