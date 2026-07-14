# usar "make -f Makefile" desde la raíz del repo UVM; este archivo solo define
# variables y la regla genérica de directorios (no contiene targets de trabajo)

SHELL := /bin/bash
FECHA := $(shell date +%d_%H_%M_%S)
#############################################################################
# Folders del ambiente UVM
SIM        := sim
BIN        := bin
LOGS       := logs
LOGS_SIM   := $(LOGS)/sim
LOGS_TESTS := $(LOGS)/tests
LOGS_COV   := $(LOGS)/cov
WARNINGS   := $(LOGS)/warnings
REPORT_CSV := reportes_csv

DIRS       := $(BIN) $(LOGS_SIM) $(LOGS_TESTS) $(LOGS_COV)

$(DIRS):
	mkdir -p $@

#----------------------------
# variables generales del entorno de simulación
#----------------------------
# SEED   : semilla de simulación (auto -> +ntb_random_seed_automatic)
# TIMEOUT: YES -> el timeout dentro del ambiente sobreescribe este plusarg, 5000000=5ms
SEED    := auto
TIMEOUT := 5000000,YES

#----------------------------
# Flags Macros
#----------------------------
# make testbench ANSI=1 para mostrar el mensaje con formato ANSI
# make testbench R=1    para compilación recursiva (-R)
MSG_FORMAT := $(if $(filter 1,$(ANSI)),+define+MSG_ANSI_FORMAT)
RECURSIVE  := $(if $(filter 1,$(R)),-R)

#----------------------------
# vcs - compilador/simulador
#----------------------------
VCS       := vcs
TIMESCALE := 1ns/1ps
SVFLAGS   := -Mupdate -full64 -sverilog -ntb_opts uvm-1.2
FILELIST  := scripts/filelist.f
EXE_SIM   := $(SIM)/testbench_sim
LOG_TB    := $(LOGS_SIM)/testbench_compile.log
MDIR      := $(BIN)
DFLAGS    := -kdb -debug_acc+all -debug_region+cell+encrypt
VERBOSITY := UVM_HIGH
LINT      := TFIPC-L
COVERAGE  := line+tgl+cond+fsm+branch+assert
CM_LOG    := $(LOGS_COV)/cm.log

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

#----------------------------
# exports hacia sim_make.mk
#----------------------------
# sim_make.mk se ejecuta con -C sim; estas variables deben ser visibles allí
export LOGS_SIM LOGS_TESTS VERBOSITY SEED TIMEOUT

# TARGET en blanco, útil para forzar de ser necesario la sobreescritura de un archivo
FORCE:

.PHONY: FORCE

####################################################################################
#################### Targets: universales
all: clean_all build_reference_model_obj testbench _grep_warnings
remake: build_reference_model_obj testbench _grep_warnings
include scripts/.ansi_code.mk
include sim/sim_make.mk

# alias de compatibilidad; los targets dependen de la regla genérica $(DIRS)
_mkdir_folders: | $(DIRS)

####################################################################################
################### Modelo de referencia C (delegado)
# construye reference_model.o con GCC y los flags IEEE 754 críticos;
# crea adems librera estatica softfloat
# la lógica completa vive en reference_model/{Makefile, make_common.mk}
build_reference_model_obj:
	$(MAKE) -C $(REF_DIR) -f Makefile $@

####################################################################################
################### Compilación del top testbench (VCS-UVM)
# Mejor usar Camino A para compilar (ver si vcs compila con flags C)
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
	grep -i -C 10 "warning" $(LOG_TB) > $(WARNINGS).log

####################################################################################
################### Ejecución de tests (sim/sim_make.mk)
run_all: testbench_sim all_test


####################################################################################
################### Targets: de limpieza
clean:
	rm -f ucli.key
	rm -rf $(MDIR)
	find $(SIM) -mindepth 1 ! -name "sim_make.mk" -delete

clean_all: clean
	rm -rf $(LOGS)/ $(REPORT_CSV)
	$(MAKE) -C $(REF_DIR) -f Makefile clean_all

####################################################################################
help:
	echo "TODO HELP FUNCTION"

# TODO: ACTUALIZAR PHONY
.PHONY: \
	all \
	_mkdir_folders \
	build_reference_model_obj \
	testbench \
	_grep_warnings \
	run_all \
	clean \
	clean_all \
	help