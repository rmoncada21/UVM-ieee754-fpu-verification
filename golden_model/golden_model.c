#include <stdlib.h>
#include <stdio.h>
#include "softfloat.h" // librería de berkeley


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

static uint_fast8_t map_rmode(uint32_t rm){
    switch (rm) {
        case 0: return softfloat_round_near_even;   /* RNE */
        case 1: return softfloat_round_minMag;      /* RTZ */
        case 2: return softfloat_round_min;         /* RDN */
        case 3: return softfloat_round_max;         /* RUP */
        case 4: return softfloat_round_near_maxMag; /* RMM */
        default: return softfloat_round_near_even;
    }
}

void fpu_golden (
    unsigned int   op_code_i,
    unsigned int   fp_a_i,
    unsigned int   fp_b_i,
    unsigned int   fp_c_i,
    unsigned int   r_mode_i,
    unsigned int  *fp_result_o,
    unsigned char *flags_o ) 
{
	float32_t    a, b, c, z, res;
    uint_fast8_t fl = 0; // flags

    a.v = (uint32_t)fp_a_i; // v = uint32_t ; typedef struct { uint32_t v; } float32_t;
    b.v = (uint32_t)fp_b_i;
    c.v = (uint32_t)fp_c_i;
    res.v = 0u;

    /* RISC-V detecta tininess después del redondeo */
    softfloat_detectTininess = softfloat_tininess_afterRounding;

	// TODO: // implementar gating del dut
	switch(op_code_i){
		default:
			res.v = 0u;
			fl = 0;
			break;
	}
	return;
}