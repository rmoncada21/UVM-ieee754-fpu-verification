# Catálogo de targets — Makefiles del ambiente UVM (FPU RV32F)

Referencia de los targets definidos en `Makefile` (raíz) y `sim/sim_make.mk`
(incluido desde la raíz, por lo que el `cwd` de `make` es siempre la raíz del
repo). Los comandos asumen que se ejecutan desde la raíz del ambiente UVM.

## Contenido

- [1. Variables / knobs relevantes](#1-variables--knobs-relevantes)
- [2. Jerarquía de salidas](#2-jerarquía-de-salidas)
- [3. Tests activos (`TESTS_ACTIVOS`)](#3-tests-activos-tests_activos)
- [4. Targets universales](#4-targets-universales)
- [5. Construcción](#5-construcción)
- [6. Ejecución / regresión](#6-ejecución--regresión)
- [7. Cobertura](#7-cobertura)
- [8. Limpieza](#8-limpieza)
- [9. Utilidad / internos](#9-utilidad--internos)
- [10. Flujos de uso](#10-flujos-de-uso)
  - [Flujo A — ejecución completa](#flujo-a--ejecución-completa)
  - [Flujo B — en dos partes](#flujo-b--en-dos-partes)
  - [Flujo C — paso a paso (control de semillas)](#flujo-c--paso-a-paso-control-de-semillas)

---

## 1. Variables / knobs relevantes

Todas se sobreescriben desde la línea de comandos (`make target VAR=valor`).

| Variable | Default | Rol |
|---|---|---|
| `FECHA` | `date +%Y%m%d_%H%M%S` | Timestamp ordenable. |
| `REG_ID` | `$(FECHA)` | Identificador/etiqueta de la regresión. Agrupa bajo `reportes/regresiones/<REG_ID>`. |
| `SEED` | aleatoria (sorteada **una** vez por invocación) | Semilla explícita y reproducible. |
| `SEEDS` | `469078601 1238983584 4170956088` | Lista de semillas fijas por defecto (las 3 usadas en el análisis de resultados). |
| `NUM_SEEDS` | `1` | Cantidad de semillas aleatorias a sortear **solo si `SEEDS` está vacío**. |
| `TEST` | `fpu_base_test` | Test a correr en `regresion`. |
| `COV_DIR` | `reportes` | VDB de cobertura a procesar (`urg`/`verdi`). |
| `VERBOSITY` | `UVM_HIGH` | `+UVM_VERBOSITY`. |
| `COVERAGE` | `line+tgl+cond+branch+assert` | Métricas `-cm` (sin `fsm`). |
| `ANSI` | — | `ANSI=1` → mensaje de compilación con formato ANSI. |
| `R` | — | `R=1` → compilación recursiva VCS (`-R`). |

Derivada importante:

- `DIR_ANALISIS`: carpeta que consumen los targets de cobertura. Es `REG_DIR`
  **solo si `REG_ID` se pasó por línea de comandos**; en cualquier otro caso es
  `reportes/ultima` (symlink a la regresión más reciente).

---

## 2. Jerarquía de salidas

La unidad de organización es la **corrida** (`<test> × <seed>`):

```text
reportes/regresiones/<REG_ID>/<test_name>/s<SEED>/
    cmd.txt          # comando exacto ejecutado
    sim.log          # log de VCS
    consola.log      # stdout+stderr (tee)
    scoreboard.csv   # resultado por transacción
    resumen.csv      # transacciones,num_pass,num_bug,num_fail
    cov.vdb/         # cobertura de la corrida
reportes/regresiones/<REG_ID>/manifest.csv        # 1 fila por corrida (índice p/ Python)
reportes/regresiones/<REG_ID>/info_regresion.txt  # commit UVM + commit DUT + fecha
reportes/ultima -> regresiones/<REG_ID>           # symlink a la más reciente
```

Artefactos de compilación (separados de la ejecución):

```text
sim/testbench_sim        # ejecutable
sim/testbench_sim.vdb    # design VDB (cobertura de compilación, sin datos de run)
```

> El **design VDB** (`sim/testbench_sim.vdb`) siempre va como primer `-covdir`
> (verdi) y primer `-dir` (urg); sin él la jerarquía de cobertura aparece vacía.

---

## 3. Tests activos (`TESTS_ACTIVOS`)

```text
fpu_base_test           fpu_test_arith_normal   fpu_test_flag_arith
fpu_test_special_spec   fpu_test_norm_spec      fpu_test_rounding
fpu_test_cmp            fpu_test_subnormal_arith fpu_test_known_bugs
```

`regresion_all` itera sobre esta lista. Cada uno tiene su target
`run_<test>` (p. ej. `run_fpu_test_cmp`).

---

## 4. Targets universales

`all` — modelo de referencia + UVM de cero, tests con las 3 semillas y todos los reportes HTML (individuales + fusionado):

```bash
make all
# = clean_all + build_reference_model_obj + testbench + regresion_mas_reportes_html
```

`remake` — recompila sin borrar el historial de `reportes/` ni el
`reference_model`; limpia solo artefactos de `sim/` y `verdi`:

```bash
make remake
# = clean (sim+verdi) + build_reference_model_obj + testbench
```

`regresion_mas_reportes_html` — corre todos los tests en regresión + genera los
reportes de cobertura (individual por test/semilla y fusionado):

```bash
make regresion_mas_reportes_html
# = regresion_all + cobertura_urg_individual_all + cobertura_urg_fusionada
```

Diferencia clave: `all` usa `clean_all` (borra también `reportes/` y el
`reference_model`), mientras `remake` usa `clean` (conserva `reportes/` y el
objeto del modelo de referencia).

---

## 5. Construcción

`build_reference_model_obj` — compila `reference_model.o` (GCC, flags IEEE 754
críticos) y la librería estática `softfloat.a`; delega en
`reference_model/{Makefile, make_common.mk}`:

```bash
make build_reference_model_obj
```

`testbench` — compila el top con VCS-UVM (`-ntb_opts uvm-1.2`), enlaza
`reference_model.o` y `softfloat.a` como argumentos posicionales, activa
cobertura y lint:

```bash
make testbench
# opcionales:
make testbench ANSI=1   # mensaje de compilación con formato ANSI
make testbench R=1      # compilación recursiva (-R)
```

---

## 6. Ejecución / regresión

`run_<test>` — corre un test concreto con la `SEED` actual (una corrida):

```bash
make run_fpu_test_cmp SEED=469078601
```

`regresion` — un test, varias semillas, bajo el mismo `REG_ID`:

```bash
# reproducir semillas exactas (recomendado):
make regresion TEST=fpu_test_cmp SEEDS="469078601 1238983584 4170956088"

# N semillas aleatorias -> hay que VACIAR SEEDS (ver corrección C2):
make regresion TEST=fpu_test_arith_normal SEEDS= NUM_SEEDS=10

# etiquetar la regresión:
make regresion TEST=fpu_test_rounding SEEDS="469078601" REG_ID=mi_etiqueta
```

`regresion_all` — todos los `TESTS_ACTIVOS`, bajo el mismo `REG_ID`:

```bash
make regresion_all SEEDS="469078601 1238983584 4170956088"  # semillas fijas de análisis por defecto
make regresion_all SEEDS= NUM_SEEDS=5                        # 5 semillas aleatorias por test
make regresion_all                                          # usa las 3 semillas por defecto
```

---

## 7. Cobertura

`cobertura_urg_individual` — reporte HTML `urg` de **una** `cov.vdb`
(design VDB + la corrida indicada):

```bash
make cobertura_urg_individual \
  COV_DIR=./reportes/regresiones/<REG_ID>/<test_name>/s<SEED>/cov.vdb
```

`cobertura_urg_individual_all` — un reporte HTML por cada `cov.vdb` de la
regresión resuelta por `DIR_ANALISIS` (la pedida con `REG_ID=`, o `ultima`):

```bash
make cobertura_urg_individual_all
make cobertura_urg_individual_all REG_ID=20260728_203146
```

`cobertura_urg_fusionada` — fusiona todas las `cov.vdb` de la regresión en
`cobertura_fusionada.vdb` y genera el reporte `cobertura_fusionada_reporte_html`:

```bash
make cobertura_urg_fusionada
make cobertura_urg_fusionada REG_ID=20260728_203146
```

`verdi` — abre la GUI de Verdi con el design VDB + el `COV_DIR` indicado.
Si `COV_DIR` **no** apunta a un `cobertura_fusionada.vdb`, primero regenera el
reporte individual (`cobertura_urg_individual`) como dependencia:

```bash
# cobertura individual de un test/semilla:
make verdi COV_DIR=./reportes/regresiones/<REG_ID>/<test_name>/s<SEED>/cov.vdb

# cobertura fusionada (sin dependencia previa):
make verdi COV_DIR=./reportes/regresiones/<REG_ID>/cobertura_fusionada.vdb
# equivalente por symlink:
make verdi COV_DIR=./reportes/ultima/cobertura_fusionada.vdb
```

---

## 8. Limpieza

```bash
make clean          # artefactos de sim/ (salvo sim_make.mk) + verdi + ucli.key + bin/
make clean_reportes # SOLO el historial de corridas (reportes/)
make clean_local    # clean + clean_reportes
make clean_all      # limpieza completa UVM + reference_model
```

Sub-targets internos: `clean_sim`, `clean_verdi`.

---

## 9. Utilidad / internos

```bash
make MOSTRAR_EXE_ABS   # imprime la ruta absoluta de testbench_sim
make _grep_warnings    # extrae warnings del log de compilación
make help              # (stub: "TODO HELP FUNCTION")
```

`_mkdir_folders` es un alias de compatibilidad que crea `bin/`, `reportes/`,
`verdi_logs/`.

---

## 10. Flujos de uso

### Flujo A — ejecución completa

Corre toda la simulación con las 3 semillas por defecto  y genera todos los
reportes HTML (individuales + fusionado):

```bash
make all
```

### Flujo B — en dos partes

Recompila (conservando historial) y luego corre regresión + reportes, usando las 3 semillas por defecto:

```bash
make remake
make regresion_mas_reportes_html
```

Abrir Verdi:

```bash
make verdi COV_DIR=./reportes/regresiones/<REG_ID>/<test_name>/s<SEED>/cov.vdb
make verdi COV_DIR=./reportes/regresiones/<REG_ID>/cobertura_fusionada.vdb
```

### Flujo C — paso a paso (control de semillas)

```bash
make remake
# equivalente explícito:
make clean_all
make build_reference_model_obj
make testbench
```

Rama 1 — regresión por test individual:

```bash
make regresion TEST=<NAME_TEST> SEEDS= NUM_SEEDS=N      # N semillas aleatorias
make regresion TEST=<NAME_TEST> SEEDS="SEED1 SEED2 SEEDN"

make cobertura_urg_individual \
  COV_DIR=./reportes/regresiones/<REG_ID>/<test_name>/s<SEED>/cov.vdb

make verdi \
  COV_DIR=./reportes/regresiones/<REG_ID>/<test_name>/s<SEED>/cov.vdb
```

Rama 2 — regresión completa (todos los tests):

```bash
make regresion_all SEEDS="SEED1 SEED2"   # semillas específicas
make regresion_all SEEDS= NUM_SEEDS=5    # N semillas aleatorias

make cobertura_urg_individual_all
make cobertura_urg_fusionada

make verdi COV_DIR=./reportes/regresiones/<REG_ID>/cobertura_fusionada.vdb
```

---