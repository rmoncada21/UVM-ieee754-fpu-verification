# Target: prerrequisites
# command to build Target

# include scripts/.ansi_code.mk
# include sim/sim_make.mk

SHELL := /bin/bash

# Folders del ambiente UVM
SIM        := sim
BIN        := bin
LOGS_SIM   := logs/sim
LOGS_TESTS := logs/tests
LOGS_COV   := logs/cov
WARNINGS   := logs/warnings
REPORT_CSV := reportes_csv

# Variables del entorno
SEED := auto

# Flags Macros
# make testbench ANSI=1 para mostrar el mensaje con formato ANSI
MSG_FORMAT := $(if $(filter 1,$(ANSI)),+define+MSG_ANSI_FORMAT)
RECURSIVE  := $(if $(filter 1, $(R)),-R)
# YES: timeout dentro del ambiente sobreescribe este plusargs, 5000000=5ms
TIMEOUT=5000000,YES

# Flags VCS
VCS 	  := vcs
TIMESCALE := 1ns/1ps
SVFLAGS   := -Mupdate -full64 -sverilog -ntb_opts uvm-1.2
FILELIST  := scripts/filelist.f
EXE_SIM   := sim/testbench_sim
LOG_TB    := logs/sim/testbench_compile.log
MDIR      := $(BIN)
DFLAGS    := -kdb -debug_acc+all -debug_region+cell+encrypt
VERBOSITY := UVM_HIGH
LINT      := TFIPC-L
COVERAGE  := line+tgl+cond+fsm+branch+assert 
CM_LOG    := logs/cov/cm.log

# Se movio al makefile el modelo
# Flags C críticos para semántica IEEE 754
# CC        := gcc
# CFLAGS    := -O2 -frounding-math -fno-unsafe-math-optimizations -ffp-contract=off

# Modelo de referencia
REF_DIR   := reference_model
REF_OBJ   := $(REF_DIR)/build/reference_model.o


# Exporta variables para que sim_make.mk las vea
export LOGS_SIM LOGS_TESTS VERBOSITY SEED TIMEOUT

# Targets
all: clean_all $(REF_MODEL) testbench _grep_warnings

include scripts/.ansi_code.mk
include sim/sim_make.mk

# mkdir -p bin/ sim/ sim/logs sim/sim_out reportes-csv reportes_log_compile
# mkdir -p bin/ sim/ logs/cov logs/sim logs/tests
_mkdir_folders:
	mkdir -p $(BIN) $(LOGS_SIM) $(LOGS_COV) $(LOGS_TESTS)

# _cp_sim_makefile:
# 	mkdir -p sim/
# 	cp -f scripts/sim_make.mk sim/

# _test: _cp_sim_makefile
# 	$(MAKE) -C sim -f sim_make.mk _test_target

_grep_warnings:
	grep -i -C 10 "warning" $(LOG_TB) > $(WARNINGS).log

####################################################################################
################### Compilar el modelo de referencia C
# $(REF_MODEL): _mkdir_folders
# 	$(CC) $(CFLAGS) -c $@/src/$(@).c -o $(SIM)/$(@).o

build_reference_model_obj:
	$(MAKE) -C reference_model -f Makefile $@

####################################################################################
################### Compilar el top testbench 
# Mejor usar Camino A para compilar (ver si vcs compila con flgas C)
testbench: _mkdir_folders
	$(VCS) $(SVFLAGS) -timescale=$(TIMESCALE) \
	-f $(FILELIST) \
	$(REF_OBJ) \
	-o $(EXE_SIM) -l $(LOG_TB) \
	-Mdir=$(MDIR) $(MSG_FORMAT) \
	$(DFLAGS) \
	+lint=$(LINT) \
	-cm $(COVERAGE) -cm_log $(CM_LOG) \
	$(RECURSIVE)
	@mv -f vc_hdrs.h .fsm.sch.verilog.xml sim 2>/dev/null || true

####################################################################################
################### ejecutar test's 
# -C sim-> cambia el working directory a sim

run_all: testbench_sim all_test

testbench_sim:
	$(MAKE) -C $(SIM) -f sim_make.mk _testbench_sim

# run_fpu_base_test:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_base_test
# run_fpu_test_arith_normal:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_test_arith_normal
# run_fpu_test_cmp:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_test_cmp
# run_fpu_test_rounding:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_test_rounding
# run_fpu_test_special_spec:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_test_special_spec
# run_fpu_test_norm_spec:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_test_norm_spec
# run_fpu_test_subnormal_arith:
# 	$(MAKE) -C $(SIM) -f sim_make.mk _sim_fpu_test_subnormal_arith

#####################################################################################
################### Limpiar archivos
clean:
	rm -f ucli.key
	rm -rf $(MDIR)
	find $(SIM) -mindepth 1 ! -name "sim_make.mk" -delete
# 	find ! -name "sim_make.mk" -delete

clean_all: clean
	rm -rf logs/ $(REPORT_CSV)

####################################################################################
################### help
#	make help, función para ver como 
help:
	echo "help"

.PHONY: all _mkdir_folders \
		testbench testbench_sim \
		run_fpu_base_test \
		build_reference_model_obj \
		clean clean_all \
		help \
