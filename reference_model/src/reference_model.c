#include <stdlib.h>
#include <stdio.h>
// librería de berkeley
#include "../../third_party/berkeley-softfloat-3/source/include/softfloat.h"


void test_dpic(int num){
	printf("DPI-C TEST from golden model -  num: %i \n", num);
	return;
}

// códigos de operacion
enum {
    OP_FADD  = 0,
	OP_FSUB  = 1,
	OP_FMUL  = 2,
	OP_FMADD = 3,
    OP_FMSUB = 4,
	OP_FEQ   = 5,
	OP_FLT   = 6,
	OP_FLE   = 7
};

static uint_fast8_t map_round_mode(uint32_t round_mode){
    switch (round_mode) {
        case 0: return softfloat_round_near_even;   /* RNE */
        case 1: return softfloat_round_minMag;      /* RTZ */
        case 2: return softfloat_round_min;         /* RDN */
        case 3: return softfloat_round_max;         /* RUP */
        case 4: return softfloat_round_near_maxMag; /* RMM */
        default: return softfloat_round_near_even;
        // cambiar default a RTZ
    }
}

void dpi_fpu_reference (
    unsigned int   op_code_i,
    unsigned int   fp_a_i,
    unsigned int   fp_b_i,
    unsigned int   fp_c_i,
    unsigned int   r_mode_i,
    unsigned int  *fp_result_o,
    unsigned char *flags_o ) {

	float32_t    fp_a, fp_b, fp_c, fp_r_mode;
    float32_t    result;
    uint_fast8_t flag = 0; // flags

    // v = uint32_t ; typedef struct { uint32_t v; } float32_t;
    fp_a.v   = (uint32_t)fp_a_i;
    fp_b.v   = (uint32_t)fp_b_i;
    fp_c.v   = (uint32_t)fp_c_i;
    result.v = (uint32_t)0;

    /* RISC-V detecta tininess después del redondeo */
    softfloat_detectTininess = softfloat_tininess_afterRounding;

	// TODO: // implementar gating del dut
	switch(op_code_i){
         //  opcode suma
        case OP_FADD:
            softfloat_roundingMode = map_round_mode(r_mode_i);
            softfloat_exceptionFlags = 0;
            result = f32_add(fp_a, fp_b);
            flag   = softfloat_exceptionFlags;
            break;
        
        // opcode de resta
        case OP_FSUB:
            softfloat_roundingMode = map_round_mode(r_mode_i);
            softfloat_exceptionFlags = 0;
            result = f32_sub(fp_a, fp_b);
            flag   = softfloat_exceptionFlags;
            break;
        
        //  opcode multiplicación
        case OP_FMUL:
            softfloat_roundingMode = map_round_mode(r_mode_i);
            softfloat_exceptionFlags = 0;
            result = f32_mul(fp_a, fp_b);
            flag   = softfloat_exceptionFlags;
            break;
        
        //  opcode operacion combinada, suma, multiplicación
        case OP_FMADD:
            break;
        
        //  opcode operacion combinada, resta, multiplicación
        case OP_FMSUB:
            break;

        //  opcode operacion comparación de igualdad
        case OP_FEQ:
            break;
        
        //  opcode operacion comparación de menor que
        case OP_FLT:
            break;

        //  opcode operacion comparación de mayor que
        case OP_FLE:
            break;

        default:
			result.v = 0u;
			flag = 0;
			break;
	}
	return;
}