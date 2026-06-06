/* test_driver.c — arnes standalone para el golden (sin VCS) */
#include <stdio.h>
#include "reference_model.h"

int main(void) {
    printf("Prueba simple para probar integración\n");
    
    unsigned int  r;
    unsigned char f;

    /* FADD 1.0 + 2.0, RNE  -> 3.0 = 0x40400000 */
    dpi_fpu_reference(0, 0x3F800000, 0x40000000, 0, 0, &r, &f);
    printf("FADD 1.0+2.0  = 0x%08X flags=0x%02X\n", r, f);

    /* FMUL min-normal(2^-126) * 0.5  -> subnormal 2^-127 = 0x00400000 */
    dpi_fpu_reference(2, 0x00800000, 0x3F000000, 0, 0, &r, &f);
    printf("FMUL subnormal= 0x%08X flags=0x%02X\n", r, f);

    /* FLT 1.0 < 2.0  -> 1 */
    dpi_fpu_reference(6, 0x3F800000, 0x40000000, 0, 0, &r, &f);
    printf("FLT 1.0<2.0   = 0x%08X flags=0x%02X\n", r, f);
    return 0;
}