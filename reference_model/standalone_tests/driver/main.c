#include <stdio.h>
#include "driver_directed.h"          /* run_suite_test + modo_e */
// #include "driver_directed_cases.h"   /* tablas de casos (extern) */

int main(void) {
    unsigned int fallos = 0;

    /* Gate real: SOLO CASOS_DIRIGIDOS en modo estricto fija el exit code */
    fallos += run_suite_test("CASOS_DIRIGIDOS", CASOS_DIRIGIDOS, N_CASOS,
            MODO_DIRECTED);

    /* Cross-check de los vectores de Testbench dirigido (no afecta el gate) */
    run_suite_test("TESTS_FPU_S", TESTS_FPU_S, N_TESTS_FPU_S, MODO_TESTBENCH);

    printf("\ndriver directed: gate -> %s (%u fallos en CASOS_DIRIGIDOS)\n",
           fallos ? "FAIL" : "PASS", fallos);

    /* Codigo de salida = gate: driver_run (pipefail) se detiene si difiere. */
    return fallos ? 1 : 0;
}