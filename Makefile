# target: prerrequisites
#	command to build target

SHELL := /bin/bash

#############################################################################
# Identificadores de corrida
#----------------------------
# FECHA  : timestamp -> ordenable con ls/sort
# REG_ID : identificador de la regresión; agrupa corridas bajo reportes/regresiones/<REG_ID>.
#          Por defecto toma FECHA; se puede etiquetar: make regresion REG_ID=my_regression
# SEED   : semilla explícita y reproducible; si no se fija se sortea UNA
#          sola vez por invocación (el guard con origin evita el re-sorteo por expansión)
FECHA := $(shell date +%Y%m%d_%H%M%S)
REG_ID   ?= $(FECHA)

ifeq ($(origin SEED), undefined)
	SEED := $(shell od -An -N4 -tu4 /dev/urandom | tr -d ' ')
endif

#############################################################################
# Folders del ambiente UVM
# sim/      : artefactos de COMPILACIÓN (ejecutable, .daidir, logs de compile)
# reportes/ : artefactos de EJECUCIÓN (una carpeta por regresión/test/semilla)
SIM         := sim
BIN         := bin
REPORTES    := reportes
REGRESIONES := $(REPORTES)/regresiones
REG_DIR     := $(REGRESIONES)/$(REG_ID)
MANIFEST    := $(REG_DIR)/manifest.csv
ULTIMA_REG  := $(REPORTES)/ultima

# se hace para la regalde cobertura
# carpeta que analizan cobertura/scripts: la REG= pedida, o 'ultima' por defecto
DIR_ANALISIS := $(if $(filter command line,$(origin REG_ID)),$(REG_DIR),$(ULTIMA_REG))

DIRS := $(BIN) $(REPORTES)

$(DIRS):
	mkdir -p $@

#----------------------------
# variables generales del entorno de simulación
#----------------------------
# TIMEOUT: YES -> el timeout dentro del ambiente sobreescribe este plusarg, 5000000=5ms
TIMEOUT := 5000000,YES

#----------------------------
# Flags Macros
#----------------------------
# make testbench ANSI=1 para mostrar el mensaje con formato ANSI
# make testbench R=1    para compilación recursiva (-R)
MSG_FORMAT := $(if $(filter 1,$(ANSI)),+define+MSG_ANSI_FORMAT)
RECURSIVE  := $(if $(filter 1,$(R)),-R)
CSV_KNOB   := ON
#----------------------------
# vcs - compilador/simulador
#----------------------------
VCS       := vcs
TIMESCALE := 1ns/1ps
SVFLAGS   := -Mupdate -full64 -sverilog -ntb_opts uvm-1.2
FILELIST  := scripts/filelist.f
EXE_SIM   := $(SIM)/testbench_sim
LOG_TB    := $(SIM)/testbench_sim_compile.log
WARNINGS  := $(SIM)/testbench_sim_compile_warnings.log
MDIR      := $(BIN)
DFLAGS    := -kdb -debug_acc+all -debug_region+cell+encrypt
VERBOSITY := UVM_HIGH
LINT      := TFIPC-L
COVERAGE  := line+tgl+cond+fsm+branch+assert
CM_LOG    := $(SIM)/testbench_sim_compile_coverage.log

#----------------------------
# reference model (delegado a reference_model/Makefile)
#----------------------------
# Los flags C críticos IEEE 754 viven en reference_model/make_common.mk:
#   -O2 -frounding-math -fno-unsafe-math-optimizations -ffp-contract=off
# Aquí solo se referencian los artefactos que VCS enlaza como argumentos
# posicionales (NO van en filelist.f)
REF_DIR := reference_model
REF_OBJ := $(REF_DIR)/build/reference_model.o
SF_LIB  := third_party/berkeley-softfloat-3/build/Linux-x86_64-GCC/softfloat.a

# TARGET en blanco, útil para forzar de ser necesario la sobreescritura de un archivo
FORCE:

.PHONY: FORCE

####################################################################################
#################### Targets: universales
all: clean build_reference_model_obj testbench
remake: clean build_reference_model_obj testbench

include scripts/.ansi_code.mk
include sim/sim_make.mk

# alias de compatibilidad; los targets dependen de la regla genérica $(DIRS)
_mkdir_folders: | $(DIRS)

####################################################################################
################### Modelo de referencia C (delegado)
# construye reference_model.o con GCC y los flags IEEE 754 críticos;
# crea además librera estatica softfloat
# la lógica completa vive en reference_model/{Makefile, make_common.mk}
build_reference_model_obj:
	$(MAKE) -C $(REF_DIR) -f Makefile $@

####################################################################################
################### Compilación del top testbench (VCS-UVM)
# enlaza el objeto del modelo y softfloat.a como argumentos posicionales
testbench: _mkdir_folders build_reference_model_obj
	$(VCS) $(SVFLAGS) -timescale=$(TIMESCALE) \
	-f $(FILELIST) \
	$(REF_OBJ) $(SF_LIB) \
	-o $(EXE_SIM) -l $(LOG_TB) \
	-Mdir=$(MDIR) $(MSG_FORMAT) \
	$(DFLAGS) \
	+lint=$(LINT) \
	-cm $(COVERAGE) -cm_log $(CM_LOG) \
	$(RECURSIVE)
	@mv -f vc_hdrs.h .fsm.sch.verilog.xml $(SIM) 2>/dev/null || true

# extrae los warnings del log de compilación a logs/warnings.log
_grep_warnings:
	grep -i -C 10 "warning" $(LOG_TB) > $(WARNINGS)

####################################################################################
################### Ejecución de tests (sim/sim_make.mk)
run_all: testbench_sim all_test

####################################################################################
################### Targets: de limpieza
# clean          : artefactos de compilación (sim/ salvo sim_make.mk, bin/, ucli.key)
# clean_reportes  : SOLO el historial de corridas (reportes/)
# clean_all      : ambos + reference_model
clean:
	rm -f ucli.key
	rm -rf $(MDIR)
	find $(SIM) -mindepth 1 ! -name "sim_make.mk" -delete

clean_reportes:
	rm -rf $(REPORTES)

clean_all: clean clean_reportes
	$(MAKE) -C $(REF_DIR) -f Makefile clean_all

####################################################################################
help:
	echo "TODO HELP FUNCTION"

# TODO: ACTUALIZAR PHONY
.PHONY: \
	all \
	remake \
	_mkdir_folders \
	build_reference_model_obj \
	testbench \
	_grep_warnings \
	run_all \
	clean \
	clean_reportes \
	clean_all \
	help