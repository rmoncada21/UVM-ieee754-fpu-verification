/* test_driver.c — arnes standalone para el golden (sin VCS) */
#include <stdio.h>
#include "reference_model.h"

typedef struct{
    unsigned int   opcode;
    const char    *opcode_name;
    unsigned int   fp_a, fp_b, fp_c;
    unsigned int   round_mode;
    unsigned char  result_exp;
    unsigned char  flag_exp;
    const char    *test_objective;
} directed_case_t;

int main(void) {
    printf("Prueba simple para probar integración\n");
    
    unsigned int  result;
    unsigned char flags;

    /* FADD 1.0 + 2.0, RNE  -> 3.0 = 0x40400000 */
    dpi_fpu_reference(OP_FADD, 0x3F800000, 0x40000000, 0, 0, &result, &flags);
    printf("FADD 1.0+2.0  = 0x%08X flags=0x%02X\n", result, flags);

    /* FMUL min-normal(2^-126) * 0.5  -> subnormal 2^-127 = 0x00400000 */
    dpi_fpu_reference(OP_FMUL, 0x00800000, 0x3F000000, 0, 0, &result, &flags);
    printf("FMUL subnormal= 0x%08X flags=0x%02X\n", result, flags);

    /* FLT 1.0 < 2.0  -> 1 */
    dpi_fpu_reference(OP_FLT , 0x3F800000, 0x40000000, 0, 0, &result, &flags);
    printf("FLT 1.0<2.0   = 0x%08X flags=0x%02X\n", result, flags);
    return 0;
}