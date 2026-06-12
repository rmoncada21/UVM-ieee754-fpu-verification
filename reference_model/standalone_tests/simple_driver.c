/* test_driver.c — arnes standalone para el golden (sin VCS) */
#include <stdio.h>
#include "reference_model.h"

typedef struct{
    unsigned int   opcode;
    const char    *opcode_name;
    unsigned int   fp_a, fp_b, fp_c;
    unsigned int   round_mode;
    unsigned int  result_exp;
    unsigned char  flag_exp;
    const char    *test_objective;
} directed_case_t;

// arreglo que almacena los test dirigidos
static const directed_case_t CASOS_DIRIGIDOS[] = {
/* --- FADD: camino normal, redondeo, especiales ----------------------------- */
// OP     OP_NUM       A            B       C   RM  RESULTADO   BANDERA
{OP_FADD, "FADD", 0x3F800000u, 0x40000000u, 0u, 0u, 0x40400000u, 0x00u,
 "1.0+2.0=3.0 exacto: humo del camino normal, sin banderas"},
//
{OP_FADD, "FADD", 0x3F800000u, 0x33800000u, 0u, 0u, 0x3F800000u, 0x01u,
 "1.0+2^-24 RNE: empate exacto -> par (no sube el LSB); NX"},
//
 {OP_FADD, "FADD", 0x3F800000u, 0x33800000u, 0u, 3u, 0x3F800001u, 0x01u,
 "mismo vector en RUP: sube un ULP; prueba que rm llega a SoftFloat"},
//
 {OP_FADD, "FADD", 0x7F800000u, 0xFF800000u, 0u, 0u, 0x7FC00000u, 0x10u,
 "inf+(-inf): invalida -> NV y qNaN canonica 0x7FC00000 (RISCV)"},
//
 {OP_FADD, "FADD", 0x7FC00000u, 0x3F800000u, 0u, 0u, 0x7FC00000u, 0x00u,
 "qNaN propaga canonica SIN NV (un build 8086-SSE daria 0xFFC00000)"},
/* --- FSUB ------------------------------------------------------------------ */
//
{OP_FSUB, "FSUB", 0x40400000u, 0x3F800000u, 0u, 0u, 0x40000000u, 0x00u,
 "3.0-1.0=2.0 exacto: humo de la resta"},/*  */
/* --- FMUL: normal, BUG-001 y underflow real -------------------------------- */
//
{OP_FMUL, "FMUL", 0x3FC00000u, 0x40000000u, 0u, 0u, 0x40400000u, 0x00u,
 "1.5*2.0=3.0 exacto: humo de la multiplicacion"},
//
 {OP_FMUL, "FMUL", 0x00000001u, 0x41200000u, 0u, 4u, 0x0000000Au, 0x00u,
 "TC-125 (BUG-001): subnormal*10 exacto; el DUT lo aplasta a 0 y el "
 "reporte.txt espera 0x07 (ambos mal). El modelo da el valor IEEE"},
//
 {OP_FMUL, "FMUL", 0x00800000u, 0x3F000000u, 0u, 0u, 0x00400000u, 0x00u,
 "min_normal*0.5=2^-127: resultado subnormal exacto, sin UF (afterRounding)"},
//
 {OP_FMUL, "FMUL", 0x00000001u, 0x00000001u, 0u, 0u, 0x00000000u, 0x03u,
 "tiny*tiny->0 con UF|NX: el underflow que BUG-001 silencia en el DUT"},
/* --- FMADD/FMSUB: secuencial con doble redondeo ----------------------------- */
//
{OP_FMADD, "FMADD", 0x40000000u, 0x40400000u, 0x3F800000u, 0u, 0x40E00000u, 0x00u,
 "2*3+1=7 exacto: humo del encadenado mul->add"},
//
 {OP_FMADD, "FMADD", 0x3C31D9C0u, 0x41304707u, 0xBD48427Bu, 0u, 0x3D90CCDCu, 0x01u,
 "centinela doble redondeo: secuencial=3D90CCDC, fusionado=3D90CCDB; "
 "si el modelo usara f32_mulAdd/fmaf() este caso FALLA"},
//
 {OP_FMSUB, "FMSUB", 0x40000000u, 0x40400000u, 0x3F800000u, 0u, 0x40A00000u, 0x00u,
 "2*3-1=5 exacto: humo de FMSUB (mul->sub, mismo doble redondeo)"},
/* --- Comparaciones: resultado 1 bit y politica flags=0 ----------------------- */
//
{OP_FEQ, "FEQ ", 0x3F800000u, 0x3F800000u, 0u, 0u, 0x00000001u, 0x00u,
 "1.0==1.0 -> 1; comparacion basica"},
//
 {OP_FLT, "FLT ", 0x3F800000u, 0x40000000u, 0u, 0u, 0x00000001u, 0x00u,
 "1.0<2.0 -> 1; comparacion basica"},
//
 {OP_FLT, "FLT ", 0x7F800001u, 0x3F800000u, 0u, 0u, 0x00000000u, 0x00u,
 "sNaN<1.0 -> 0 con flags=0 (politica del DUT): SoftFloat crudo daria NV=0x10"},
//
 {OP_FLE, "FLE ", 0x40000000u, 0x40000000u, 0u, 0u, 0x00000001u, 0x00u,
 "2.0<=2.0 -> 1; cierra la cobertura de las 8 operaciones"},
};

#define CASOS_SIZE (sizeof(CASOS_DIRIGIDOS)/sizeof(CASOS_DIRIGIDOS[0]))
static const char *ROUND_MODE[5] = {"RNE", "RTZ", "RDN", "RUP", "RMM"};

int main(void) {
    unsigned int fallos = 0;

    printf("Prueba simple con (%u) casos dirigidos para probar integración \
            del modelo de referencia\n", (unsigned)CASOS_SIZE);


    

    return 0;
}