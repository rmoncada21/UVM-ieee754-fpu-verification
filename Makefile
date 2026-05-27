# Target: prerrequisites
# command to build Target

SHELL := /bin/bash

include scripts/.ansi_code.mk

# Flags C  críticos para semántica IEEE 754
CC        := gcc
CFLAGS    := -O2 -frounding-math -fno-unsafe-math-optimizations
REF_MODEL := golden_model/golden_model.c
REF_OBJ   := sim/golden_model.o

# -- Compilar el modelo de referencia C --------------------------------------
$(REF_OBJ): $(REF_MODEL) | _mkdir_folders
	$(CC) $(CFLAGS) -c $< -o $@


# Target: all
#	make all, ejecuta todo el ambiente de pruebas
all:

_mkdir_folders:
	mkdir -p bin/ sim/ sim/logs sim/sim_out reportes-csv reportes_log

testbench: _mkdir_folders
	vcs -Mupdate -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
	-f scripts/filelist.f \
	$(REF_OBJ) \
	-CFLAGS "$(CFLAGS)" \
	-o sim/sim_out/testbench_sim \
	-l sim/logs/compile.log \
	-Mdir=bin +define+NO_MSG_ANSI_FORMAT \
	-kdb -debug_acc+all -debug_region+cell+encrypt \
	+lint=TFIPC-L -cm line+tgl+cond+fsm+branch+assert 
	@mv -f vc_hdrs.h .fsm.sch.verilog.xml sim 2>/dev/null || true


clean:
	rm -f ucli.key
	rm -rf bin/ sim/


# Target: help
#	make help, función para ver como 
help:

.PHONY:
