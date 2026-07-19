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

    // Banderas 
    typedef struct packed {
        logic nv, // bit 4: invalid
        logic dz, // bit 3: divide by zero/ infinite
        logic ov, // bit 2: overflow
        logic uf, // bit 1: underflow
        logic nx  // bit 0: inexact
    } fpu_ref_flags_s;

    // resultado completo del modelo de referencia
    typedef struct {
        logic [C_FP_WIDTH-1:0] resultado;
        fpu_ref_flags_s flags;
    } fpu_ref_resultado_s;

    // Frontera DPI-C — contrato en reference_model.h:
    //   void dpi_fpu_reference(unsigned int op_code, a_bits, b_bits,
    //                          c_bits, rm, unsigned int *r_bits,
    //                          unsigned char *flags);
    //  (int unsigned <-> unsigned int; output <-> puntero, por ABI DPI)
    import "DPI-C" function void dpi_fpu_reference(
        // entradas
        input  int  unsigned op_code_i,
        input  int  unsigned fp_a_i,
        input  int  unsigned fp_b_i,
        input  int  unsigned fp_c_i,
        input  int  unsigned r_mode_i,
        // salidas
        output int  unsigned fp_result_o,
        output byte unsigned flags_o
    );

    // funcion calcular, extraer datos del modelo
    function automatic fpu_ref_resultado_s fpu_ref_calcular(
        // solo entradas
        input fpu_op_code_e          op_code_i_pkg,
        input logic [C_FP_WIDTH-1:0] fp_a_i_pkg,
        input logic [C_FP_WIDTH-1:0] fp_b_i_pkg,
        input logic [C_FP_WIDTH-1:0] fp_c_i_pkg,
        input fpu_r_mode_e           r_mode_i_pkg
    );
        int unsigned resultado_dpi;
        byte unsigned flag_dpi;

        fpu_ref_resultado_s reference_model_resultado;
        
        // llamada a función dpi, con entrada de datos del mismo pkg
        dpi_fpu_referencia (
            int'(op_code_i_pkg),
            fp_a_i_pkg,
            fp_b_i_pkg,
            fp_c_i_pkg,
            int'(r_mode_i_pkg),
            // salidas, importadas a las variables dentro del package
            resultado_dpi,
            flag_dpi // 
        );

        // mapear las variables un solo struct
        reference_model_resultado.resultado = resultado_dpi;
        reference_model_resultado.flags = fpu_ref_flags_s'(flag_dpi[4:0]);
        
        return reference_model_resultado;

    endfunction : fpu_ref_calcular

endpackage : fpu_dpic_ref_model_pkg

import fpu_dpic_ref_model_pkg::*;

`endif // FPU_DPIC_REF_MODEL_PKG