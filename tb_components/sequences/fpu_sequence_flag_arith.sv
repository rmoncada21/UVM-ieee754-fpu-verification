/*
 * File:    fpu_sequence_flag_arith.sv
 * - Project:  FPU RV32F Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test flag_arith (testplan sec. 2.2.1.2, versión
 *   corregida). Reparte num_items_rand transacciones de forma uniforme
 *   entre tres familias de estímulo dirigido:
 *     FAM_OVERFLOW  : resultado supera el máximo finito representable.
 *     FAM_UNDERFLOW : resultado tiny con pérdida de exactitud (solo
 *                     FMUL: con FMADD/FMSUB el producto tiny y c normal
 *                     caen en el caso pendiente TFG-##22 / UDF_MADD).
 *     FAM_INVALID   : operación inválida IEEE ? inf-inf, 0×inf, inf×0
 *                     y NaN entrante; el DUT la conflaciona con
 *                     overflow/underflow (BUG-003).
 *   El modo de redondeo es aleatorio entre los 5 válidos; las banderas
 *   se disparan en todos los modos (solo cambia el valor del resultado,
 *   que resuelve el modelo de referencia).
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

class fpu_sequence_flag_arith_c extends fpu_base_sequence_c;
    `uvm_object_utils(fpu_sequence_flag_arith_c)

    // Prototipos de las funciones de la secuencia
    extern function new(string name = "fpu_sequence_flag_arith_c");
    extern virtual task body();

endclass : fpu_sequence_flag_arith_c

// Implmentación de las funciones
function fpu_sequence_flag_arith_c::new(string name = "fpu_sequence_flag_arith_c");
    super.new(name);
endfunction : new

// Task: body
// Reparto uniforme y determinista (i % 3) entre FAM_OVERFLOW,
// FAM_UNDERFLOW (solo FMUL) y FAM_INVALID
task fpu_sequence_flag_arith_c::body();
    fpu_seq_item_c item;
    fpu_familia_flag_e familia;
    logic [C_FP_WIDTH-1:0] operando_a;

    `uvm_info(get_type_name(),
        $sformatf("Inicio de la secuencia flag_arith: %0d items", num_items_rand),
        UVM_MEDIUM)


    for(int i=0; i<num_items_rand; i++) begin
        familia = fpu_familia_flag_e'(i%3);
        item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

        start_item(item);

            if (familia == FAM_UNDERFLOW) begin
                if (!item.randomize() with { op_code_i == FMUL; }) begin
                    `uvm_error(get_type_name(),
                               $sformatf("Falló el randomize del item %0d", i))
                end
            end else begin
                if (!item.randomize() with { op_code_i inside {FADD, FSUB, FMUL, FMADD, FMSUB}; }) begin
                    `uvm_error(get_type_name(), 
                               $sformatf("Fallo el randomize del item %0d", i))
                end
            end

            // tercer operando por defecto normal en banda segura
            item.fp_c_i = gen_normal_banda();

            case(item.op_code_i)
                // resultado supera el máximo finito representable
                FAM_OVERFLOW : begin
                    case(item.op_code_i)
                        FADD: begin
                            // exp 254 en ambos y mismo signo |a+b| >=2^128
                            operando_a  = gen_operando(CLASE_NORMAL_OVF_SUMA);
                            item.fp_a_i = operando_a;
                            item.fp_b_i = gen_operando(CLASE_NORMAL_OVF_SUMA, int'(operando_a[C_FP_WIDTH-1]));
                        end
                        FSUB: begin
                            // exp 254 en ambos y mismo signo |a+b| >=2^128
                            operando_a  = gen_operando(CLASE_NORMAL_OVF_SUMA);
                            item.fp_a_i = operando_a;
                            item.fp_b_i = gen_operando(CLASE_NORMAL_OVF_SUMA, operando_a[C_FP_WIDTH-1] ? 0 : 1);
                        end
                        // FMUL, FMADD, FMSUB: producto siempre en overflow;
                        // en FMADD/FMSUB, inf +- c normal se mantiene en inf
                        default: begin
                            item.fp_a_i = gen_operando(CLASE_NORMAL_OVF_PROD);
                            item.fp_b_i = gen_operando(CLASE_NORMAL_OVF_PROD);
                        end
                    endcase
                end
                // resultado tiny (bajo el minimo normal), casi siempre inexacto
                FAM_UNDERFLOW : begin
                    item.fp_a_i = gen_operando(CLASE_NORMAL_UDF_PROD);
                    item.fp_b_i = gen_operando(CLASE_NORMAL_UDF_PROD);
                end
                // operacion invalida IEEE
                FAM_INVALID : begin
                    case (item.op_code_i)
                        FADD : begin // inf + (-inf)
                            operando_a  = gen_inf();
                            item.fp_a_i = operando_a;
                            item.fp_b_i = gen_inf(operando_a[C_FP_WIDTH-1] ? 0 : 1);
                        end
                        FSUB : begin // inf - inf (mismo signo)
                            operando_a  = gen_inf();
                            item.fp_a_i = operando_a;
                            item.fp_b_i = gen_inf(int'(operando_a[C_FP_WIDTH-1]));
                        end
                        FMUL : begin // 0 x inf
                            item.fp_a_i = gen_cero();
                            item.fp_b_i = gen_inf();
                        end
                        FMADD : begin // (inf x 0) + c
                            item.fp_a_i = gen_inf();
                            item.fp_b_i = gen_cero();
                        end
                        default : begin // FMSUB: NaN entrante
                            item.fp_a_i = gen_qnan();
                            item.fp_b_i = gen_normal_banda();
                        end
                    endcase
                end

            endcase

        finish_item(item);
    end

endtask : body