/*
 * File:    fpu_types_seq_pkg.sv
 * - Project:  FPU RV32F — Verificación funcional UVM
 *
 * Description:
 *   Tipos auxiliares de la capa de estímulo (tests/sequences).
 *   Define los anchos de campo del formato binary32 y la clasificación
 *   IEEE 754 de un operando, usada por fpu_seq_constraints_c y por los
 *   generadores dirigidos de fpu_base_sequence_c.
 *
 * Dependencies:
 *   (ninguna)
 */

`ifndef FPU_TYPES_CONSTRAINTS_PKG
`define FPU_TYPES_CONSTRAINTS_PKG

package fpu_types_constraints_pkg;
    
    // anchos de campo del formato IEEE 754 binary32
    localparam int C_EXP_WIDTH = 8; // exponente
    localparam int C_MANT_WIDTH = 23; // mantissa

    // limites del campo del exponente (sesgo)
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_MIN_NORMAL = 8'd1;   // normal: menor
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_MAX_NORMAL = 8'd254; // normal: mayor
    localparam logic [C_EXP_WIDTH-1:0] C_EXP_ESPECIAL   = 8'd255; // inf / NaN (s, q)

    // banda segura para arimética normal (tesplan sec. 2.2.1.1):
    // operandos normales y sin resultados de over/underflow para
	// FADD/FSUB/FMUL/FMADD/FMSUB
	localparam logic [C_EXP_WIDTH-1:0] C_EXP_BANDA_MINIMA = 8'd70;
	localparam logic [C_EXP_WIDTH-1:0] C_EXP_BANDA_MAXIMA = 8'd184;

    // clasificacion IEEE 754 de un operando binary32
     typedef enum int {
        CLASE_CERO      = 0, // ±0
        CLASE_SUBNORMAL = 1, // exp = 0, mantisa != 0
        CLASE_NORMAL    = 2, // exp en [1, 254]
        CLASE_INF       = 3, // ±inf
        CLASE_QNAN      = 4, // NaN silencioso (mantisa[22] = 1)
        CLASE_SNAN      = 5, // NaN señalizador (mantisa[22] = 0, payload != 0)
		// bandas  - subconjuntos de valores
		CLASE_NORMAL_BANDA = 6 // normal en banda segura [70,184]
     } fpu_clase_operando_e;

endpackage

import fpu_types_constraints_pkg::*;

`endif // FPU_TYPES_CONSTRAINTS_PKG
