/* test_driver.c — arnes standalone para el golden (sin VCS) */
#include <stdio.h>
#include "../include/reference_model.h"

int main(void) {
    printf("Prueba simple para probar integración\n");
    
    unsigned int  round_mode;
    unsigned char flags;

    /* FADD 1.0 + 2.0, RNE  -> 3.0 = 0x40400000 */
    dpi_fpu_reference(OP_FADD, 0x3F800000, 0x40000000, 0, 0, &round_mode, &flags);
    printf("FADD 1.0+2.0  = 0x%08X flags=0x%02X\n", round_mode, flags);

    /* FMUL min-normal(2^-126) * 0.5  -> subnormal 2^-127 = 0x00400000 */
    dpi_fpu_reference(OP_FMUL, 0x00800000, 0x3F000000, 0, 0, &round_mode, &flags);
    printf("FMUL subnormal= 0x%08X flags=0x%02X\n", round_mode, flags);

    /* FLT 1.0 < 2.0  -> 1 */
    dpi_fpu_reference(OP_FLT , 0x3F800000, 0x40000000, 0, 0, &round_mode, &flags);
    printf("FLT 1.0<2.0   = 0x%08X flags=0x%02X\n", round_mode, flags);
    return 0;
}