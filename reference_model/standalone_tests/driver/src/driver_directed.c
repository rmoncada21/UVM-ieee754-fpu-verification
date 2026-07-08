#include <stdio.h>
#include "reference_model.h"
#include "driver_directed.h"          /* modo_e + prototipo propio */
//#include "driver_directed_cases.h"   /* typedef + tablas (extern) */

static const char *ROUND_MODE[5] = {"RNE", "RTZ", "RDN", "RUP", "RMM"};

static int calcular_tolerancia(unsigned int valor_actual,
                               unsigned int valor_esperado) {
    /* $signed de 32 bits, igual que verify_output */
    long actual = (int)valor_actual, esperado = (int)valor_esperado;
    return (actual >= esperado - 1) && (actual <= esperado + 1);
}

/* Corre una tanda. Devuelve fallos de GATE (siempre 0 en MODO_TESTBENCH). */
unsigned int run_suite_test(const char *nombre_casos,
                            const directed_case_t *casos,
                            unsigned int n_casos, modo_e modo) {
    unsigned int fallos_gate = 0;
    unsigned int exactos = 0;
    unsigned int tolerancia = 0;
    unsigned int diverge = 0;

    printf("\n=== %s (%u casos, modo %s) ===\n", nombre_casos, n_casos,
           modo == MODO_DIRECTED ? "ESTRICTO result+flags" :
            "TESTBENCH dirigido result-only +-1ULP");

    for (unsigned int i = 0; i < n_casos; i++) {
        const directed_case_t *test = &casos[i];
        unsigned int  dpi_result;
        unsigned char dpi_flag;

        dpi_fpu_reference(test->op_code, test->fp_a, test->fp_b, test->fp_c,
                          test->rm, &dpi_result, &dpi_flag);

        int resultado_exacto = (dpi_result == test->result_exp);
        int resultado_ok = (modo == MODO_DIRECTED) ? resultado_exacto :
            calcular_tolerancia(dpi_result, test->result_exp);

        /* TESTBENCH dirigido: flags no se juzgan */
        int flag_ok = (modo == MODO_DIRECTED) ? (dpi_flag == test->flag_exp) :
            1;

        int ok   = resultado_ok && flag_ok;

        const char *etiqueta;
        if (modo == MODO_DIRECTED) {
            etiqueta = ok ? "PASS" : "FAIL";
            if (!ok) fallos_gate++;
        } else {
            if (resultado_exacto)  {
                etiqueta = "OK  "; exactos++;
            /* Testbench dirigido != IEEE pero dentro de 1 ULP */
            } else if (resultado_ok) {
                etiqueta = "~ULP"; tolerancia++;
            /* divergencia real (esperada) */
            } else {
                etiqueta = "DIVE"; diverge++;
            }
        }

        printf("[%s] %3u %s fp_a = %08X fp_b = %08X fp_c = %08X %s -> \
                esperado = %08X resultado = %08X flag = %02X",
                etiqueta, i + 1, test->op_code_name, test->fp_a, test->fp_b,
                test->fp_c, ROUND_MODE[test->rm], test->result_exp, dpi_result,
                dpi_flag);

        if (!ok || (modo == MODO_TESTBENCH && !resultado_exacto))
            printf("(resultado_esperado=%08X flag_esperada=%02X)",
                    test->result_exp, test->flag_exp);

        printf("\n         %s\n", test->test_objective);
    }

    if (modo == MODO_DIRECTED)
        printf("--- %s: %u/%u PASS, %u FAIL\n",
                nombre_casos, n_casos - fallos_gate, n_casos, fallos_gate);
    else
        printf("--- %s: %u exactos, %u dentro de 1 ULP, %u divergencias \
                (informativo, no gate)\n",
                nombre_casos, exactos, tolerancia, diverge);

    return fallos_gate;
}