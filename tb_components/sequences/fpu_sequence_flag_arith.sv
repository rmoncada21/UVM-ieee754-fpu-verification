/*
 * File:    fpu_sequence_flag_arith.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test flag_arith (testplan sec. 2.2.1.2, versión
 *   corregida). Reparte num_items_rand transacciones de forma uniforme
 *   entre tres familias de estímulo dirigido:
 *     FAM_OVERFLOW  : resultado supera el máximo finito representable.
 *     FAM_UNDERFLOW : resultado tiny con pérdida de exactitud (solo
 *                     FMUL: con FMADD/FMSUB el producto tiny y c normal
 *                     caen en el caso pendiente TFG-##22 / UDF_MADD).
 *     FAM_INVALID   : operación inválida IEEE — inf−inf, 0×inf, inf×0
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
    logic [C_FP_WIDTH-1:0] fp_a_seq;

endtask : body