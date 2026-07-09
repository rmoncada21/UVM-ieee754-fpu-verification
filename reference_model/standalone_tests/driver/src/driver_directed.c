
/****************************************************************************************
 * File:    simple_driver.c
 * Project: FPU RV32F - Verificacion funcional UVM, subambiente de validacion
 * Author:
 *
 * Descripcion:
 *   Arnes de humo AUTOJUEZ del modelo de referencia (N3). Cada caso lleva su
 *   resultado y banderas esperados, verificados contra Berkeley SoftFloat
 *   (SPECIALIZE_TYPE=RISCV, tininess afterRounding). El programa compara,
 *   imprime PASS/FAIL por caso y retorna distinto de cero si algo difiere:
 *   con el pipefail del Makefile, ddirected_case_triver_run se convierte en gate real.
 *
 *   Que ejercita (una pasada, sin entradas externas):
 *     - Las 8 operaciones del DUT: FADD FSUB FMUL FMADD FMSUB FEQ FLT FLE
 *     - La perilla de redondeo (mismo vector en RNE y RUP da distinto bit)
 *     - NaN canonica RISCV 0x7FC00000 (delata un build 8086-SSE: 0xFFC00000)
 *     - Banderas: NV en inf-inf, NX en empates, UF|NX en underflow real
 *     - Subnormales como OPERANDO (patron BUG-001, TC-125 del reporte.txt):
 *       el modelo NO replica el flush del DUT; por eso el scoreboard lo caza
 *     - Doble redondeo en FMADD: vector donde secuencial != fusionado; si
 *       alguien cambia el modelo a f32_mulAdd/fmaf(), este caso FALLA
 *     - Politica flags=0 en comparaciones (sNaN: SoftFloat crudo daria NV)
 *
 * Uso:  make all_driver        (compila y corre via driver_run, queda log)
 *       ./bin/simple_driver_exe   (manual; exit 0 = todo PASS)
 ****************************************************************************************/
/* ====================================================================================
 *  TESTS_FPU_S  -  Vectores dirigidos extraidos de tb_fp_alu.sv (Samuel Cabrera).
 *  Reusa el typedef directed_case_t de simple_driver.c (mismo orden de campos).
 *
 *  ADVERTENCIA flag_exp: el TB de Samuel NO define banderas esperadas; verify_output
 *  solo compara el resultado (con tolerancia +-1 ULP) y verify_cmp solo el bit. Por
 *  eso flag_exp queda en 0x00 como MARCADOR, no como expectativa verificada. No pasar
 *  este arreglo por el autojuez de banderas sin poblarlas antes (p.ej. capturando
 *  softfloat_exceptionFlags del modelo de referencia por vector).
 *
 *  result_exp es el valor ESPERADO POR SAMUEL, transcrito verbatim (incluye los que
 *  su baseline trae mal; ver nota al pie del chat). El #NN del objetivo es su indice
 *  original dentro de cada arreglo; el TC-global del reporte.txt se deriva sumando.
 * ==================================================================================== */
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