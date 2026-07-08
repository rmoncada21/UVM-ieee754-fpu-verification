#ifndef DRIVER_DIRECTED_H
#define DRIVER_DIRECTED_H

// #include "driver_directed_cases.h"   /* directed_case_t */

/* Un caso dirigido: entradas + veredicto esperado (resultado Y banderas).
 * Banderas SoftFloat: NX=0x01 UF=0x02 OF=0x04 DZ=0x08 NV=0x10               */
typedef struct {
    unsigned int  op_code;
    const char   *op_code_name;
    unsigned int  fp_a, fp_b, fp_c;
    unsigned int  rm;
    unsigned int  result_exp;
    unsigned char flag_exp;
    const char   *test_objective;
} directed_case_t;

/* Tablas definidas en test_vectors_fpu.c (enlace externo). El conteo NO puede
 * salir de sizeof aqui (via extern el arreglo es de tamano incompleto); por eso
 * se exporta como variable calculada en la TU que define cada tabla.           */

extern const directed_case_t CASOS_DIRIGIDOS[];
extern const unsigned int     N_CASOS;
extern const directed_case_t TESTS_FPU_S[];
extern const unsigned int     N_TESTS_FPU_S;


/* Modo de juicio de una tanda:
 * MODO_DIRECTED : gate estricto, resultado exacto Y banderas.
 * MODO_TESTBENCH: cross-check informativo, result-only +-1 ULP.             */
typedef enum { MODO_DIRECTED, MODO_TESTBENCH } modo_e;

static int calcular_tolerancia(unsigned int valor_actual,
                               unsigned int valor_esperado);

/* Corre una tanda. Devuelve fallos de GATE (siempre 0 en MODO_TESTBENCH). */
unsigned int run_suite_test(const char *nombre_casos,
                            const directed_case_t *casos,
                            unsigned int n_casos, modo_e modo);

#endif /* DRIVER_DIRECTED_H */