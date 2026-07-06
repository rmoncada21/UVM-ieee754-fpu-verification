#include <stdlib.h>
#include <stdio.h>
#include "../../third_party/berkeley-softfloat-3/source/include/softfloat.h"

/* 
    Dejar de momento para cuando se haga el merge, no romper la compilación
    con el testbench
*/

void test_dpic(int num){
    printf("DPI-C TEST from golden model -  num: %i \n", num);
    return;
}

/* Códigos de operación, idénticos al DUT (fp_alu.sv) */
enum {
    OP_FADD  = 0, OP_FSUB  = 1, OP_FMUL = 2, OP_FMADD = 3,
    OP_FMSUB = 4, OP_FEQ   = 5, OP_FLT  = 6, OP_FLE   = 7
};

/* Modo de redondeo RISC-V -> SoftFloat (mismo orden: identidad, con guarda) */
static uint_fast8_t map_rmode(uint32_t rm) {
    switch (rm) {
        case 0: return softfloat_round_near_even;   /* RNE */
        case 1: return softfloat_round_minMag;      /* RTZ */
        case 2: return softfloat_round_min;         /* RDN */
        case 3: return softfloat_round_max;         /* RUP */
        case 4: return softfloat_round_near_maxMag; /* RMM */
        default: return softfloat_round_near_even;
    }
}
// función amulador de la FPU
void dpi_fpu_reference(
    unsigned int   op_code_i,
    unsigned int   fp_a_i,
    unsigned int   fp_b_i,
    unsigned int   fp_c_i,
    unsigned int   r_mode_i,
    unsigned int  *fp_result_o,
    unsigned char *flags_o)
{
    float32_t a, b, c, z, res;
    uint_fast8_t fl = 0;

    a.v = (uint32_t)fp_a_i;
    b.v = (uint32_t)fp_b_i;
    c.v = (uint32_t)fp_c_i;
    res.v = 0u;

    /* RISC-V detecta tininess después del redondeo */
    softfloat_detectTininess = softfloat_tininess_afterRounding;

    switch (op_code_i) {
        case OP_FADD:
            softfloat_roundingMode   = map_rmode(r_mode_i);
            softfloat_exceptionFlags = 0;
            res = f32_add(a, b);
            fl  = softfloat_exceptionFlags;
            break;

        case OP_FSUB:
            softfloat_roundingMode   = map_rmode(r_mode_i);
            softfloat_exceptionFlags = 0;
            res = f32_sub(a, b);
            fl  = softfloat_exceptionFlags;
            break;

        case OP_FMUL:
            softfloat_roundingMode   = map_rmode(r_mode_i);
            softfloat_exceptionFlags = 0;
            res = f32_mul(a, b);
            fl  = softfloat_exceptionFlags;
            break;

        case OP_FMADD: {
            /* Doble redondeo deliberado: mul en RNE, suma en el modo */
            uint_fast8_t fl_mul, fl_add;
            softfloat_roundingMode   = softfloat_round_near_even;
            softfloat_exceptionFlags = 0;
            z      = f32_mul(a, b);
            fl_mul = softfloat_exceptionFlags;
            softfloat_roundingMode   = map_rmode(r_mode_i);
            softfloat_exceptionFlags = 0;
            res    = f32_add(z, c);
            fl_add = softfloat_exceptionFlags;
            fl     = (uint_fast8_t)(fl_mul | fl_add);
            break;
        }

        case OP_FMSUB: {
            /* fp_mul(a,b) en RNE, luego fp_sub(z, c) en el modo */
            uint_fast8_t fl_mul, fl_sub;
            softfloat_roundingMode   = softfloat_round_near_even;
            softfloat_exceptionFlags = 0;
            z      = f32_mul(a, b);
            fl_mul = softfloat_exceptionFlags;
            softfloat_roundingMode   = map_rmode(r_mode_i);
            softfloat_exceptionFlags = 0;
            res    = f32_sub(z, c);
            fl_sub = softfloat_exceptionFlags;
            fl     = (uint_fast8_t)(fl_mul | fl_sub);
            break;
        }

        case OP_FEQ:
            softfloat_exceptionFlags = 0;
            // convertir booleano a 1, 0, tipoo
            res.v = f32_eq(a, b) ? 1u : 0u;
            fl    = 0;   /* el DUT fuerza banderas a 0 en comparaciones */
            break;

        case OP_FLT:
            softfloat_exceptionFlags = 0;
            res.v = f32_lt(a, b) ? 1u : 0u;
            fl    = 0;
            break;

        case OP_FLE:
            softfloat_exceptionFlags = 0;
            res.v = f32_le(a, b) ? 1u : 0u;
            fl    = 0;
            break;

        default:
            res.v = 0u;
            fl    = 0;
            break;
    }

    *fp_result_o = (unsigned int)res.v;
    *flags_o     = (unsigned char)(fl & 0x1F);
}
