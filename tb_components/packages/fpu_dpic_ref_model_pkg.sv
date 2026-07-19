/*
 * File:    fpu_dpi_pkg.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Paquete dedicado a la frontera DPI-C del modelo de referencia
 *   (convención sec. 21: los import "DPI-C" se agrupan en un package
 *   exclusivo). Declara dpi_fpu_reference() (reference_model.c, Berkeley
 *   SoftFloat SPECIALIZE_TYPE=RISCV) y expone golden_calcular() como
 *   único punto de entrada para el scoreboard: llama al DPI y devuelve
 *   un golden_result_s ya desempaquetado (resultado binary32 + banderas
 *   fflags decodificadas en golden_flags_s). También centraliza el
 *   import de test_dpic (humo de la frontera, usado por testbench.sv).
 *
 * Dependencies:
 *   fpu_types_pkg.sv (fpu_op_code_e, fpu_r_mode_e, C_FP_WIDTH),
 *   reference_model/include/reference_model.h (contrato C),
 *   reference_model/src/reference_model.c (DPI-C, enlazado con softfloat.a)
 */

`ifndef FPU_DPIC_REF_MODEL_PKG
`define FPU_DPIC_REF_MODEL_PKG

package fpu_dpic_ref_model_pkg;
    
    // Importar funciones DPIC
    import "DPI-C" function void test_dpic(input int num);

    // Frontera DPI-C — contrato en reference_model.h:
    //   void dpi_fpu_reference(unsigned int op_code, a_bits, b_bits,
    //                          c_bits, rm, unsigned int *r_bits,
    //                          unsigned char *flags);
    //  (int unsigned <-> unsigned int; output <-> puntero, por ABI DPI)
    import "DPI-C" function void dpi_fpu_reference(
        input  int  unsigned op_code_i,
        input  int  unsigned fp_a_i,
        input  int  unsigned fp_b_i,
        input  int  unsigned fp_c_i,
        input  int  unsigned r_mode_i,
        output int  unsigned fp_result_o,
        output byte unsigned flags_o
    );

endpackage : fpu_dpic_ref_model_pkg

import fpu_dpic_ref_model_pkg::*;

`endif // FPU_DPIC_REF_MODEL_PKG