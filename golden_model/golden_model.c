#include <stdlib.h>
#include <stdio.h>
#include "softfloat.h" // librería de berkeley

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

static uint_fast8_t map_rmode(uint32_t rm)
{
    switch (rm) {
        case 0: return softfloat_round_near_even;   /* RNE */
        case 1: return softfloat_round_minMag;      /* RTZ */
        case 2: return softfloat_round_min;         /* RDN */
        case 3: return softfloat_round_max;         /* RUP */
        case 4: return softfloat_round_near_maxMag; /* RMM */
        default: return softfloat_round_near_even;
    }
}

void test_dpic(int num){
	printf("DPI-C TEST from golden model -  num: %i \n", num);
	return;
}
