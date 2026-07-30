# Catálogo de targets — Makefiles del modelo de referencia (SoftFloat/TestFloat)

Referencia de los targets definidos en `reference_model/Makefile` (raíz del
modelo), `make_common.mk` (variables comunes) y los tres módulos standalone
`standalone_tests/{runner,driver,replayer}/make_<x>.mk`. Los comandos asumen que
se ejecutan desde `reference_model/` (o `make -C reference_model <target>` desde
la raíz del repo UVM). El ambiente UVM invoca aquí únicamente
`build_reference_model_obj` para producir `reference_model.o`.

## Contenido

- [1. Variables clave (`make_common.mk`)](#1-variables-clave-make_commonmk)
- [2. Conjuntos de operaciones y modos de redondeo](#2-conjuntos-de-operaciones-y-modos-de-redondeo)
- [3. Jerarquía de salidas](#3-jerarquía-de-salidas)
- [4. Targets universales](#4-targets-universales)
- [5. Build de librerías y objeto del modelo](#5-build-de-librerías-y-objeto-del-modelo)
- [6. Herramientas TestFloat (vectores y verificación N1)](#6-herramientas-testfloat-vectores-y-verificación-n1)
- [7. Runner — validación cruzada](#7-runner--validación-cruzada)
- [8. Driver — casos dirigidos](#8-driver--casos-dirigidos)
- [9. Replayer — auditoría con TestFloat](#9-replayer--auditoría-con-testfloat)
- [10. Limpieza](#10-limpieza)

---

## 1. Variables clave (`make_common.mk`)

`make_common.mk` define muchas variables (rutas de carpetas, logs y `bin/` por
módulo); aquí solo las de suma importancia. Las overridables (`?=`) se
sobreescriben desde la línea de comandos.

| Variable | Default | Rol |
|---|---|---|
| `ARCH_TARGET` | `RISCV` | Especialización de SoftFloat/TestFloat (`SPECIALIZE_TYPE`). |
| `PLATFORM_SOFT` / `PLATFORM_TEST` | `Linux-x86_64-GCC` | Plataforma de build Berkeley; ambas deben coincidir. |
| `SOFTFLOAT_DIR` | `../third_party/berkeley-softfloat-3` | Raíz de SoftFloat (override `?=`). |
| `TESTFLOAT_DIR` | `../third_party/berkeley-testfloat-3` | Raíz de TestFloat (override `?=`). |
| `CC` | `gcc` | Compilador del modelo y de los standalone. |
| `CFLAGS` | `-O2 -frounding-math -fno-unsafe-math-optimizations -ffp-contract=off` | Flags IEEE 754 críticos (redondeo exacto, sin contracción FMA). |
| `TF_LEVEL` | `1` | Nivel de vectores TestFloat (`1`≈46.5 K por op×modo; `2`=millones). |
| `TF_SEED` | `1` | Semilla de `testfloat_gen` (reproducibilidad). |
| `VAL_N` | `500` | Vectores procesados bajo valgrind (≈20–50× más lento). |
| `CLANG` | `clang` | Compilador para sanitizers. |
| `SANITIZERS` | `address memory undefined` | Sanitizers usados (asan/msan/ubsan). |
| `REF_MODEL` | `reference_model` | Base de `REF_C`/`REF_OBJ`/`REF_EXE`. |
| `FECHA` | `date +%d_%H_%M_%S` | Sella las carpetas de logs por corrida. |

Nombres base de los ejecutables standalone (override `?=`):
`RUNNER_FILE=runner_testfloat`, `DRIVER_FILE=driver_directed`,
`REPLAYER_FILE=replayer_testfloat`.

---

## 2. Conjuntos de operaciones y modos de redondeo

```text
ROUND_MODE_PAIR  rne:-rnear_even  rtz:-rminMag  rdn:-rmin  rup:-rmax  rmm:-rnear_maxMag
TF_OPS_ALL       f32_add f32_sub f32_mul f32_eq f32_lt f32_le   # N1 (testsoftfloat)
OPS_ARITH        f32_add f32_sub f32_mul                        # aritméticas con redondeo
OPS_CMP          f32_eq  f32_lt  f32_le                         # comparación (sin redondeo)
SWEEP_OPS        f32_add f32_sub f32_mul f32_mulAdd f32_mulSub  # barrido CSV (replayer)
```

`ROUND_MODE_PAIR` mapea token RISC-V (`rne/rtz/rdn/rup/rmm`) al flag de TestFloat.
En el barrido, `f32_mulSub` reutiliza los vectores de `f32_mulAdd` (parte 2 del pipe).

---

## 3. Jerarquía de salidas

```text
reference_model/
├── build/reference_model.o           # objeto del modelo (lo enlaza el ambiente UVM)
├── vectors/*.tf                       # vectores TestFloat generados
├── csv/*.csv                          # salidas del sweep del replayer
├── logs/<FECHA>/{build,testsoftfloat,vectores}/
└── standalone_tests/
    ├── runner/{bin/, logs/<FECHA>/{compile,sanitizers,valgrind}/}
    ├── driver/{bin/, logs/<FECHA>/{compile,sanitizers,valgrind}/}
    └── replayer/{bin/, logs/<FECHA>/{compile,sanitizers,valgrind}/}

../third_party/berkeley-softfloat-3/build/Linux-x86_64-GCC/softfloat.a
../third_party/berkeley-testfloat-3/build/Linux-x86_64-GCC/{testfloat_gen,testfloat_ver,testsoftfloat,...}
```

Cada `bin/` contiene el ejecutable base (`*_exe`) y sus variantes de sanitizer
(`*_asan`, `*_msan`, `*_ubsan`). `FECHA` usa el formato `%d_%H_%M_%S`.

---

## 4. Targets universales

`all` — pipeline completo del modelo de referencia:

```bash
make all
# = build_all + all_runner + all_driver + all_replayer
```

`build_all` — solo la construcción (librerías Berkeley + objeto del modelo):

```bash
make build_all
# = build_berkeley_softfloat + build_berkeley_testfloat + reference_model.o
```

Agregados por módulo (cada uno = run + valgrind + sanitizers):

```bash
make all_runner     # runner_run_matrix + runner_valgrind_all + runner_sanitizers_all
make all_driver     # driver_run + driver_valgrind_all + driver_sanitizers_all
make all_replayer   # replayer_run_matrix + replayer_valgrind_all + replayer_sanitizers_all
```

---

## 5. Build de librerías y objeto del modelo

`build_berkeley_softfloat` / `build_berkeley_testfloat` — construyen las
librerías Berkeley con `SPECIALIZE_TYPE=$(ARCH_TARGET)`; ambas deben coincidir:

```bash
make build_berkeley_softfloat     # genera softfloat.a
make build_berkeley_testfloat     # genera testfloat_gen, testfloat_ver, testsoftfloat, ...
```

`build_reference_model_obj` — compila `reference_model.o` (objetivo `$(REF_OBJ)`)
con GCC y los flags IEEE 754 críticos; es el único target que consume el
ambiente UVM:

```bash
make build_reference_model_obj
```

---

## 6. Herramientas TestFloat (vectores y verificación N1)

`test_build_berkeleys_libraries` — N1: valida el `softfloat.a` generado contra
`slowfloat` (FP íntegro de Berkeley) vía `testsoftfloat`, por operación × modo:

```bash
make test_build_berkeleys_libraries
```

`build_testfloat_vectors` — genera los vectores `.tf` en `vectors/`
(`OPS_ARITH` + `f32_mulAdd` × modos, y `OPS_CMP`):

```bash
make build_testfloat_vectors
make build_testfloat_vectors TF_LEVEL=2 TF_SEED=7   # más vectores, otra semilla
```

Pruebas sueltas de TestFloat (knobs `_my_TF_SEED`, `_my_TF_LEVEL`, `_my_RM`,
`_my_OP`): `_testfloat_gen`, `_testfloat_ver`, `_testfloat_test` (pipe
`gen | ver`).

---

## 7. Runner — validación cruzada

Concepto: `testfloat_gen | runner_exe <modo> <op>`. El runner compara el modelo
de referencia contra los vectores generados directamente (sin `testfloat_ver`).

```bash
make all_runner                  # run_matrix + valgrind + sanitizers
make runner_compile              # compila runner_testfloat_exe
make runner_run_default_case     # 1 caso: f32_mul RNE
make runner_run_matrix           # OPS_ARITH×5 modos + OPS_CMP = 18 corridas
```

Knob de trazado `RUNNER_TRACE` (`0`=silencioso, `N`=primeros N, `all`=todos):

```bash
make runner_run_matrix RUNNER_TRACE=all
```

Análisis dinámico (agregados; sub-targets entre paréntesis):

```bash
make runner_valgrind_all     # memcheck + massif + callgrind
make runner_sanitizers_all   # asan + msan + ubsan
# compilar solo una variante de sanitizer:
make runner_compile_asan     # (o _msan / _ubsan)
```

---

## 8. Driver — casos dirigidos

Concepto: autojuez con casos inyectados desde `main.c` (`driver_directed` +
`_cases.c`); enlaza `reference_model.o`. No usa TestFloat.

```bash
make all_driver              # run + valgrind + sanitizers
make driver_compile          # compila driver_directed_exe
make driver_run              # ejecuta los casos dirigidos
```

Análisis dinámico:

```bash
make driver_valgrind_all     # memcheck + massif + callgrind
make driver_sanitizers_all   # asan + msan + ubsan
make driver_compile_asan     # (o _msan / _ubsan)
```

---

## 9. Replayer — auditoría con TestFloat

Concepto: `testfloat_gen | replayer_exe | testfloat_ver`. El replayer emite en
formato TestFloat para que `testfloat_ver` verifique el resultado.

```bash
make all_replayer              # run_matrix + valgrind + sanitizers
make replayer_compile          # compila replayer_testfloat_exe
make replayer_check_fast       # pipe rápido: f32_add RNE (gen | replayer | ver)
make replayer_run_matrix       # auditoría por op×modo (gen | replayer | ver)
```

`replayer_testfloat_sweep` — genera los CSV en `csv/` (barrido `SWEEP_OPS`,
modo `--csv`; `f32_mulSub` reusa vectores de `f32_mulAdd`):

```bash
make replayer_testfloat_sweep
```

Análisis dinámico:

```bash
make replayer_valgrind_all     # memcheck + massif + callgrind
make replayer_sanitizers_all   # asan + msan + ubsan
make replayer_compile_asan     # (o _msan / _ubsan)
```

---

## 10. Limpieza

```bash
make clean                  # locales al modelo: bin/ + logs/ + vectors/
make clean_berkeley         # objetos/.a de softfloat y testfloat + vectores .tf + tools
make clean_build_reference  # build/ (reference_model.o)
make clean_all              # clean + clean_berkeley + clean_build_reference
```

Sub-targets internos: `clean_bin`, `clean_logs`, `clean_vectors`,
`clean_berkeley_softfloat`, `clean_berkeley_testfloat`.

---