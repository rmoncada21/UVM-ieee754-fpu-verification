`ifndef FPU_TYPES_PKG
`define FPU_TYPES_PKG
    
package fpu_types_pkg;

    localparam int C_OP_CODE_WIDTH = 3; // opcode (8 operaciones: 5 aritmeticas, 3 comparacion)
    localparam int C_FP_WIDTH = 32;     // fp_a_i, fp_b_i, fp_c_i
    localparam int C_R_MODE = 3;        // r_mode (5 modos)

    parameter p_addr_width = 3; // definir luego en el makefile

    // clasificación del modo de operación del DUT
    typedef enum logic [C_OP_CODE_WIDTH-1:0]{
        FADD = 3'd0,
        FSUB = 3'd1,
        FMUL = 3'd2,
        FMADD = 3'd3,
        FMSUB = 3'd4,
        FEQ = 3'd5,
        FLT = 3'd6,
        FLE = 3'd7
    } fpu_op_code_e;
    
    // clasificación del modo de redondeo del DUT
    typedef enum logic [C_R_MODE-1:0]{
        RNE = 3'b000,
        RTZ = 3'b001,
        RDN = 3'b010,
        RUP = 3'b011,
        RMM = 3'b100
    } fpu_r_mode_e;

endpackage: fpu_types_pkg;

import fpu_types_pkg::*;

`endif // FPU_TYPES_PKG
