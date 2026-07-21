// Language: SystemVerilog
/*
 * File:    fpu_sequence_arith_normal.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Secuencia del test arith_normal (testplan sec. 2.2.1.1). Envía
 *   num_items_rand transacciones aritméticas (FADD, FSUB, FMUL, FMADD,
 *   FMSUB) con modo de redondeo aleatorio válido y los tres operandos
 *   normales en la banda segura de exponente [70, 184], que garantiza
 *   operandos y resultados normales, sin overflow, underflow, valores
 *   especiales ni subnormales (no interfiere con BUG-001).
 *
 * Dependencies:
 *   fpu_base_sequence.sv, fpu_seq_constraints.sv, fpu_types_seq_pkg.sv
 */

class fpu_sequence_arith_normal_c extends fpu_base_sequence_c;
    `uvm_object_utils(fpu_sequence_arith_normal_c)

    // Prototipos de funciones de la secuencia
    extern function new(string name = "fpu_sequence_arith_normal_c");
    extern virtual task body();

endclass : fpu_sequence_arith_normal_c


function fpu_sequence_arith_normal_c::new(string name = "fpu_sequence_arith_normal_c");
    super.new(name);
endfunction : new

// Task: body
// Envía num_items_rand transacciones aritméticas (FADD, FSUB, FMUL,
// FMADD, FMSUB) con modo de redondeo aleatorio válido y operandos
// normales en banda segura (signo y mantisa libres).
task fpu_sequence_arith_normal_c::body();
    fpu_seq_item_c item;

    `uvm_info(get_type_name(),
        $sformatf("Inicio de secuencia arith_normal: %0d items", num_items_rand),
        UVM_MEDIUM)

    for (int i = 0; i < num_items_rand; i++) begin
        item = fpu_seq_item_c::type_id::create($sformatf("item_%0d", i));

        start_item(item);
        // operacion aritmetica y modo de redondeo valido, aleatorios
        if (!item.randomize() with {
            op_code_i inside {FADD, FSUB, FMUL, FMADD, FMSUB};
        })
            `uvm_error(get_type_name(),
                $sformatf("Fallo el randomize del item %0d", i))
        // operandos normales en banda segura (signo y mantisa libres)
        item.fp_a_i = gen_normal_banda();
        item.fp_b_i = gen_normal_banda();
        item.fp_c_i = gen_normal_banda();
        finish_item(item);

        `uvm_info(get_type_name(),
            $sformatf("Item %0d enviado: opcode=%s rm=%s fp_a=%8h fp_b=%8h fp_c=%8h",
                i, item.op_code_i.name(), item.r_mode_i.name(),
                item.fp_a_i, item.fp_b_i, item.fp_c_i),
            UVM_HIGH)
    end

    `uvm_info(get_type_name(), "Fin de secuencia arith_normal", UVM_MEDIUM)
endtask : body