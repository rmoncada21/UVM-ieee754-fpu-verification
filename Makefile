# Target: prerrequisites
# command to build Target

SHELL := /bin/bash
include scripts/.ansi_code.mk

# Flags C  críticos para semántica IEEE 754
CC        := gcc
CFLAGS    := -O2 -frounding-math -fno-unsafe-math-optimizations
REF_MODEL := golden_model/golden_model.c
REF_OBJ   := sim/golden_model.o

# Flags VCS
VCS 	  := vcs
TIMESCALE := 1ns/1ps
SVFLAGS   := -Mupdate -full64 -sverilog -ntb_opts uvm-1.2
FILELIST  := scripts/filelist.f
EXE_SIM   := sim/testbench_sim
LOG_TB    := logs/sim/testbench_compile.log
MDIR      := bin
DFLAGS    := -kdb -debug_acc+all -debug_region+cell+encrypt
VERBOSITY := UVM_HIGH
LINT      := TFIPC-L
COVERAGE  := line+tgl+cond+fsm+branch+assert 
CM_LOG    := logs/cov/cm.log

# Flags Macros 
# make testbench ANSI=1 para mostrar el mensaje con formato ANSI
MSG_FORMAT := $(if $(filter 1,$(ANSI)),+define+MSG_ANSI_FORMAT)
RECURSIVE  := $(if $(filter 1, $(R)),-R)

# Variables
SEED := 

# Targets
all: $(REF_OBJ) testbench

# mkdir -p bin/ sim/ sim/logs sim/sim_out reportes-csv reportes_log_compile
_mkdir_folders:
	mkdir -p bin/ sim/ logs/cov logs/sim logs/tests

_cp_sim_makefile:
	mkdir -p sim/
	cp -f scripts/sim_make.mk sim/

_test: _cp_sim_makefile
	make -C sim -f sim_make.mk _test_target

# ---------------------------------------------
# -- Compilar el top testbench
testbench: _mkdir_folders
	$(VCS) $(SVFLAGS) -timescale=$(TIMESCALE) \
	-f $(FILELIST) \
	$(REF_OBJ) "$(CFLAGS)" \
	-o $(EXE_SIM) -l $(LOG_TB) \
	-Mdir=$(MDIR) $(MSG_FORMAT) \
	$(DFLAGS) \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+lint=$(LINT) \
	-cm $(COVERAGE) -cm_log $(CM_LOG) \
	$(RECURSIVE)
	@mv -f vc_hdrs.h .fsm.sch.verilog.xml sim 2>/dev/null || true

# ---------------------------------------------
# -- ejecutar test's 
# -C sim-> cambia el working directory a sim

testbench_sim: _cp_sim_makefile
	make -C sim -f sim_make.mk _testbench_sim

sim_fpu_base_test: _cp_sim_makefile
	make -C sim -f sim_make.mk _sim_fpu_base_test

# ---------------------------------------------
# -- Compilar el modelo de referencia C
ref_model: $(REF_MODEL) | _mkdir_folders
	$(CC) $(CFLAGS) -c $< -o $@

$(REF_OBJ): $(REF_MODEL) | _mkdir_folders
	$(CC) $(CFLAGS) -c $< -o $@

# ---------------------------------------------
# limpiar archivos
clean:
	rm -f ucli.key
	rm -rf bin/ sim/

clean_all: clean
	rm -rf logs/ reportes_csv/

# ---------------------------------------------
# Target: help
#	make help, función para ver como 
help:
	echo "help"

.PHONY: all _mkdir_folders _cp_sim_makefile _test \
		testbench testbench_sim \
		sim_fpu_base_test \
		clean clean_all \
		help \
