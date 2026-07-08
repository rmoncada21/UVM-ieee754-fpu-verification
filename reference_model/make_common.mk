# usar "make -f make_ref_soft.mk" si se encuentra dentro del directorio de golde_model/

SHELL := /bin/bash
FECHA := $(shell date +%d_%H_%M_%S)
#############################################################################
# Folders del ambiente
REF_BIN       = bin
REF_SRC       = src
REF_INC       = include
REF_LOGS      = logs
RUN_LOGS      = $(REF_STAND)/runner/logs
DRV_LOGS      = $(REF_STAND)/driver/logs
REP_LOGS      = $(REF_STAND)/replayer/logs
RUN_LOGS_F    = $(REF_STAND)/runner/logs/$(FECHA)
DRV_LOGS_F    = $(REF_STAND)/driver/logs/$(FECHA)
REP_LOGS_F    = $(REF_STAND)/replayer/logs/$(FECHA)
REF_BUILD     = build
REF_VECTORS   = vectors
REF_CSV       = csv

# Folders logs
REF_STAND     = standalone_tests
LOGS_BUILD    := $(REF_LOGS_F)/build
LOGS_TFSOFT   := $(REF_LOGS_F)/testsoftfloat
LOGS_VECTORS  := $(REF_LOGS_F)/vectores 
RUN_BIN       := $(REF_STAND)/runner/bin
LOGS_RUN_C    := $(RUN_LOGS_F)/compile
LOGS_RUN_SAN  := $(RUN_LOGS_F)/sanitizers
LOGS_RUN_VAL  := $(RUN_LOGS_F)/valgrind
DRV_BIN       := $(REF_STAND)/driver/bin
LOGS_DRV_C    := $(DRV_LOGS_F)/compile
LOGS_DRV_SAN  := $(DRV_LOGS_F)/sanitizers
LOGS_DRV_VAL  := $(DRV_LOGS_F)/valgrind
REP_BIN       := $(REF_STAND)/replayer/bin
LOGS_REP_C    := $(REP_LOGS_F)/compile
LOGS_REP_SAN  := $(REP_LOGS_F)/sanitizers
LOGS_REP_VAL  := $(REP_LOGS_F)/valgrind

LOG_DIRS      := $(LOGS_BUILD) $(LOGS_TFSOFT) $(LOGS_VECTORS) \
				 $(RUN_LOGS) $(DRV_LOGS) $(REP_LOGS) \
				 $(RUN_BIN) $(LOGS_RUN_C) $(LOGS_RUN_SAN) $(LOGS_RUN_VAL)   \
				 $(DRV_BIN) $(LOGS_DRV_C) $(LOGS_DRV_SAN) $(LOGS_DRV_VAL)    \
				 $(REP_BIN) $(LOGS_REP_C) $(LOGS_REP_SAN) $(LOGS_REP_VAL)
DIRS          := $(REF_BUILD) $(REF_VECTORS) $(REF_CSV) $(LOG_DIRS)

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
INCLUDES   := -Iinclude -I$(SF_INCLUDE) -I$(INC_RUN) -I$(INC_DRV) -I$(INC_REP)
# para revisar sintaxis
# CSOURCES    = $(wildcard $(REF_SRC)/*.c)
# TODO: Corregir CTEST -> para la regla CFILES__syntax
# CTEST       = $(wildcard $(REF_STAND)/*.c)
# HFILES      = $(wildcard $(REF_INC)/*.h)
# CFILES      = $(CSOURCES) $(CTEST) $(HFILES)

#----------------------------
# valgrind
#----------------------------
# TODO: AGREGAR Valgrind tools, USAR AL MODULARIZAR FUNCIONES
# VALGRIND_TOOLS = memcheck massif callgrind

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
# runner
#----------------------------
RUNNER_FILE   ?= runner_testfloat
RUNNER_MAIN_C := $(REF_STAND)/runner/main.c
RUNNER_C      := $(REF_STAND)/runner/src/$(RUNNER_FILE:=.c)
RUNNER_EXE    := $(RUN_BIN)/$(RUNNER_FILE:=_exe)
RUNNER_ASAN   := $(RUN_BIN)/$(RUNNER_FILE:=_asan)
RUNNER_MSAN   := $(RUN_BIN)/$(RUNNER_FILE:=_msan)
RUNNER_UBSAN  := $(RUN_BIN)/$(RUNNER_FILE:=_ubsan)
RUNNER_RM_DEFAULT ?= -rnear_even
RUNNER_OP_DEFAULT ?= f32_mul

#----------------------------
# Driver
#----------------------------
# Archivos para inyectar datos desde el mismo archivo "main"
DRIVER_FILE    ?= driver_directed
DRIVER_C       := $(REF_STAND)/driver/src/$(DRIVER_FILE:=.c)
DRIVER_MAIN_C  := $(REF_STAND)/driver/main.c
DRIVER_CASES_C := $(REF_STAND)/driver/src/$(DRIVER_FILE:=_cases.c)
DRIVER_EXE     := $(DRV_BIN)/$(DRIVER_FILE:=_exe)
DRIVER_ASAN    := $(DRV_BIN)/$(DRIVER_FILE:=_asan)
DRIVER_MSAN    := $(DRV_BIN)/$(DRIVER_FILE:=_msan)
DRIVER_USAN    := $(DRV_BIN)/$(DRIVER_FILE:=_usan)

#----------------------------
# Replayer
#----------------------------
# Variables del testfloat replay
# Archivos para inyectar datos mediante pipe con testfloat tools
# nombre_original tf_replay  
REPLAYER_FILE   ?= replayer_testfloat
REPLAYER_MAIN_C := $(REF_STAND)/replayer/main.c
REPLAYER_C      := $(REF_STAND)/replayer/src/$(REPLAYER_FILE:=.c)
REPLAYER_EXE    := $(REP_BIN)/$(REPLAYER_FILE:=_exe)
REPLAYER_ASAN   := $(REP_BIN)/$(REPLAYER_FILE:=_asan)
REPLAYER_MSAN   := $(REP_BIN)/$(REPLAYER_FILE:=_msan)
REPLAYER_UBSAN  := $(REP_BIN)/$(REPLAYER_FILE:=_ubsan)

#----------------------------
# Variables para estudio con valgrind
# BIN_EXE    := $(wildcard $(REF_BIN)/*_exe)
# VAL_TOOLS  := memcheck helgrind

# TARGET en blanco, útil para forzar de ser necesario la sobreescritura de un archivo
FORCE:

.PHONY: FORCE
