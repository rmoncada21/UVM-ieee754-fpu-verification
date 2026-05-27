`timescale 1ns/1ps

module tb_top;



    // instancia del la interface de la fpu
    fpu_if bif(); // bus interface b-if

    // instancia del dut y conexión con la interface
    fp_alu dut( 
        .op_code_i    (bif.op_code_i),
        .fp_a_i       (bif.fp_a_i),
        .fp_b_i       (bif.fp_b_i),
        .fp_c_i       (bif.fp_c_i),
        .r_mode_i     (bif.r_mode_i),
        .fp_result_o  (bif.fp_result_o),
        .overflow_o   (bif.overflow_o),
        .underflow_o  (bif.underflow_o),
        .cmp_result_o (bif.cmp_result_o),
        .invalid_o    (bif.invalid_o)
    );


    initial begin
        uvm_config_db #(virtual fpu_if)::set(
            null,  // punto de partida de la jerarquia -> null = uvm_root
            "*",   // wildcard; para todos los componentes
            "vif", // identifcador 
            bif    // valor del identificador
        );
        // Prueba simpl de DPIC
        test_dpic(8);
        
        // iniciar los test
        // run_test();
        $finish;
    end

endmodule
