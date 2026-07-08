# usar "make -f make_ref_soft.mk" si se encuentra dentro del directorio de golde_model/

SHELL := /bin/bash
FECHA := $(shell date +%d_%H_%M_%S)
#############################################################################
# Folders del ambiente
REF_BIN       = bin
REF_SRC       = src
REF_INC       = include
REF_LOGS      = logs
REF_BUILD     = build
REF_VECTORS   = vectors
REF_CSV       = csv
REF_STAND     = standalone_tests
# STAND_BIN = standalone_tests/bin

# Folders logs
LOGS_BUILD    := $(REF_LOGS)/build
LOGS_TFSOFT   := $(REF_LOGS)/testsoftfloat
LOGS_VECTORS  := $(REF_LOGS)/vectores
LOGS_DRIVER   := $(REF_LOGS)/driver
LOGS_REPLAY   := $(REF_LOGS)/replayer
LOGS_RUNNER   := $(REF_LOGS)/runner
# Hacer mas carpetas para guardar logs/driver/valgrind logs/driver/sanitizers     ¿?
# Hacer mas carpetas para guardar logs/runner/valgrind logs/runner/sanitizers     ¿?
# Hacer mas carpetas para guardar logs/replayer/valgrind logs/replayer/sanitizers ¿?
LOGS_VALGRIND := $(REF_LOGS)/valgrind
LOGS_SAN      := $(REF_LOGS)/sanitizers

LOG_DIRS      := $(LOGS_BUILD) $(LOGS_TFSOFT) $(LOGS_VECTORS) $(LOGS_DRIVER) \
                 $(LOGS_REPLAY) $(LOGS_RUNNER) $(LOGS_VALGRIND) $(LOGS_SAN)
DIRS          := $(REF_BIN) $(REF_BUILD) $(REF_VECTORS) $(REF_CSV) $(LOG_DIRS)

$(DIRS):
	mkdir -p $@
#----------------------------
# variables generales para soft/testfloat
ARCH_TARGET       = RISCV
# Opciones: Linux-ARM-VFPv2-GCC Linux-386-GCC Linux-x86_64-GCC Win32-MinGW
# Ambas deben coincidir para una correcta integración y compilación
PLATFORM_SOFT     = Linux-x86_64-GCC
PLATFORM_TEST     = Linux-x86_64-GCC
#----------------------------
# Variables para berkeley SOFTFLOAT
SOFTFLOAT_DIR ?= ../third_party/berkeley-softfloat-3
SF_BUILD      := $(SOFTFLOAT_DIR)/build/$(PLATFORM_SOFT)
SF_LIBRARY_A  := $(SF_BUILD)/softfloat.a
SF_INCLUDE    := $(SOFTFLOAT_DIR)/source/include

#----------------------------
# Variables para berkeley TESTFLOAT
TESTFLOAT_DIR ?= ../third_party/berkeley-testfloat-3
TF_BUILD      := $(TESTFLOAT_DIR)/build/$(PLATFORM_TEST)
TF_TESTFLOAT  := $(TF_BUILD)/testfloat
TF_GEN        := $(TF_BUILD)/testfloat_gen
TF_VER        := $(TF_BUILD)/testfloat_ver
TF_SOFTFLOAT  := $(TF_BUILD)/testsoftfloat
TF_TIME       := $(TF_BUILD)/timesoftfloat
TF_TOOLS_PATHS = $(TF_TESTFLOAT) $(TF_GEN) $(TF_VER) $(TF_SOFTFLOAT) $(TF_TIME)
TF_TOOLS       = $(notdir $(TF_TOOLS_PATHS))


#----------------------------
# testfloat argumentos
#----------------------------
# TF_LEVEL: 1 = ~46.5 K vectores por (op,modo); 2 = millones (barrido nocturno)
# TF_SEED : reproducibilidad total del flujo (default de testfloat_gen: 1)
# VAL_N   : vectores bajo valgrind (es ~20-50x mas lento que nativo)
TF_LEVEL ?= 1
TF_SEED  ?= 1
VAL_N    ?= 500

# Matrices de cobertura: 5 modos de redondeo RISC-V x operaciones del DUT
# token:flag  ->  rne=RNE  rtz=RTZ  rdn=RDN  rup=RUP  rmm=RMM
ROUND_MODE_PAIR := rne:-rnear_even rtz:-rminMag rdn:-rmin rup:-rmax rmm:-rnear_maxMag
TF_OPS_ALL      := f32_add f32_sub f32_mul f32_eq f32_lt f32_le
OPS_ARITH       := f32_add f32_sub f32_mul # agregar FMADD, FMSUB 8 operaciones
OPS_CMP         := f32_eq  f32_lt  f32_le
SWEEP_OPS       := f32_add f32_sub f32_mul f32_mulAdd f32_mulSub
# ROUD_MODE_PAIR: TODO
# TF_OPS_ALL    : N1, las 6 funciones SoftFloat que el modelo llama
# OPS_ARITH     : N4, set auditable por ver (madd/msub y cmp quedan fuera del gate)
# OPS_CMP       : TODO
# SWEEP_OPS     : barrido CSV; f32_mulSub consume vectores de f32_mulAdd (parte 2)

##############################################################

#----------------------------
# gcc compilador local
#----------------------------
CC         := gcc
CFLAGS     := -O2 -frounding-math -fno-unsafe-math-optimizations -ffp-contract=off
CFSYNTAX   := -fsyntax-only
INC_RUN    := $(REF_STAND)/runner/include
INC_DRV    := $(REF_STAND)/driver/include
INC_REP    := $(REF_STAND)/replayer/include
INCLUDES   := -Iinclude -I$(SF_INCLUDE) -I$(INC_DRV)
# para revisar sintaxis
CSOURCES    = $(wildcard $(REF_SRC)/*.c)
CTEST       = $(wildcard $(REF_STAND)/*.c)
HFILES      = $(wildcard $(REF_INC)/*.h)
CFILES      = $(CSOURCES) $(CTEST) $(HFILES)

#----------------------------
# valgrind
#----------------------------
# TODO: AGREGAR Valgrind tools, USAR AL MODULARIZAR FUNCIONES
VALGRIND_TOOLS = memcheck massif callgrind

#----------------------------
# clang - sanitizers compilador
#----------------------------
# TODO: AGREGAR SANITIZERS con clang
CLANG      ?= clang
CLFLAGS    := -O1 -g -fno-omit-frame-pointer -fno-sanitize-recover=all \
			  -frounding-math -fno-unsafe-math-optimizations -ffp-contract=off

SANITIZERS := address memory undefined

#----------------------------
# reference model
#----------------------------
# Variables del modelo de referencia con softfloat
REF_MODEL ?= reference_model
REF_C     := $(REF_SRC)/$(REF_MODEL:=.c)
REF_OBJ   := $(REF_BUILD)/$(REF_MODEL:=.o)
REF_EXE   := $(REF_BIN)/$(REF_MODEL:=_exe)

#----------------------------
# Driver
#----------------------------
# Archivos para inyectar datos desde el mismo archivo "main"
DRIVER_FILE    ?= driver_directed
DRIVER_C       := $(REF_STAND)/driver/src/$(DRIVER_FILE:=.c)
DRIVER_CASES_C := $(REF_STAND)/driver/src/$(DRIVER_FILE:=_cases.c)
DRIVER_MAIN_C  := $(REF_STAND)/driver/main.c
DRIVER_EXE     := $(REF_BIN)/$(DRIVER_FILE:=_exe)
DRIVER_ASAN    := $(REF_BIN)/$(DRIVER_FILE:=_asan)
DRIVER_MSAN    := $(REF_BIN)/$(DRIVER_FILE:=_msan)
DRIVER_USAN    := $(REF_BIN)/$(DRIVER_FILE:=_usan)

#----------------------------
# runner
#----------------------------
RUNNER_FILE  ?= runner_testfloat
RUNNER_C     := $(REF_STAND)/runner/src/$(RUNNER_FILE:=.c)
RUNNER_EXE   := $(REF_BIN)/$(RUNNER_FILE:=_exe)
RUNNER_ASAN  := $(REF_BIN)/$(RUNNER_FILE:=_asan)
RUNNER_MSAN  := $(REF_BIN)/$(RUNNER_FILE:=_msan)
RUNNER_UBSAN := $(REF_BIN)/$(RUNNER_FILE:=_ubsan)

RUNNER_RM_DEFAULT ?= -rnear_even
RUNNER_OP_DEFAULT ?= f32_mul

#----------------------------
# Variables del testfloat replay
# Archivos para inyectar datos mediante pipe con testfloat tools
# nombre_original tf_replay  
REPLAYER_FILE  ?= replayer_testfloat
REPLAYER_C     := $(REF_STAND)/replayer/src/$(REPLAYER_FILE:=.c)
REPLAYER_EXE   := $(REF_BIN)/$(REPLAYER_FILE:=_exe)
REPLAYER_ASAN  := $(REF_BIN)/$(REPLAYER_FILE:=_asan)
REPLAYER_MSAN  := $(REF_BIN)/$(REPLAYER_FILE:=_msan)
REPLAYER_UBSAN := $(REF_BIN)/$(REPLAYER_FILE:=_ubsan)

#----------------------------
# Variables para estudio con valgrind
BIN_EXE    := $(wildcard $(REF_BIN)/*_exe)
VAL_TOOLS  := memcheck helgrind

# TARGET en blanco, útil para forzar de ser necesario la sobreescritura de un archivo
FORCE: