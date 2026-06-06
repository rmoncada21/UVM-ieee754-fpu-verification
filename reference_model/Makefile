# usar "make -f make_ref_soft.mk" si se encuentra dentro del directorio de golde_model/

#############################################################################
# Variables para softfloat
SOFTFLOAT_DIR ?= ../third_party/berkeley-softfloat-3
SF_BUILD      := $(SOFTFLOAT_DIR)/build/Linux-x86_64-GCC
SF_LIBRARY_A  := $(SF_BUILD)/softfloat.a
SF_INCLUDE    := $(SOFTFLOAT_DIR)/source/include

# Variables para testfloat
TESTFLOAT_DIR ?= ../third_party/berkeley-testfloat-3
TF_BUILD      := $(TESTFLOAT_DIR)/build/Linux-x86_64-GCC
TF_GEN        := $(TF_BUILD)/testfloat_gen
TF_VER        := $(TF_BUILD)/testfloat_ver
TF_OPS        := f32_add f32_sub f32_mul f32_eq f32_lt f32_le

# Compilador - probar luego con clang
CC       := gcc
CFLAGS   := -O2 -frounding-math -fno-unsafe-math-optimizations
INCLUDES := -Iinclude -I$(SF_INCLUDE)

# Folders
BIN       = bin
SRC       = src
LOGS      = logs
BUILD     = build
VECTORS   = vectores
STAND     = standalone_tests
# # STAND_BIN = standalone_tests/bin

# Variables del reference
REF_MODEL ?= reference_model
REF_C     := $(SRC)/$(REF_MODEL).c
REF_OBJ   := $(BUILD)/$(REF_MODEL:=.o)
REF_EXE   := $(BIN)/$(REF_MODEL:=_exe)
DRIVER    := $(SRC)/simple_driver.c

# Variables del testfloat replay
TF_REPLAY      = tf_replay
TF_REPLAY_C    = $(STAND)/$(TF_REPLAY:=.c)
TF_REPLAY_EXE  = $(BIN)/$(TF_REPLAY:=_exe)

# export SF_LIBRARY_A

#############################################################################
# Targets
all: clean_all all_berkeley_softfloat all_berkeley_testfloat

_mkdir_folders:
	mkdir -p $(BIN) $(BUILD) $(LOGS) $(VECTORS)

# Prueba de nombre de variables
_echo_vars:
	@echo "variable:REF_MODEL: $(REF_MODEL) "
	@echo "variable:REF_C:     $(REF_C) "
	@echo "variable:REF_OBJ:   $(REF_OBJ) "
	@echo "variable:REF_EXE:   $(REF_EXE) "
	@echo "variable:DRIVER:    $(DRIVER) "

###################################################################
all_berkeley_softfloat: build_berkeley_softfloat $(REF_MODEL:=_object) \
	$(REF_MODEL:=_driver) $(REF_MODEL:=_exe)

# construir la libreria con especializacion RISC-V, 
# esto genera softfloat.a como librería estática
# -> ../third_party/berkeley-softfloat-3/build/Linux-x86_64-GCC/softfloat.a
build_berkeley_softfloat:
	$(MAKE) -C $(SF_BUILD) SPECIALIZE_TYPE=RISCV

#----------------------------
# crear objeto reference_model.o
# reference_model_object
$(REF_MODEL:=_object): _mkdir_folders
	$(CC) $(CFLAGS) -c $(REF_C) -I$(SF_INCLUDE) -o $(REF_OBJ)

#----------------------------
# enlaza objeto y compila prueba simple
$(REF_MODEL:=_driver):
	$(CC) $(CFLAGS) $(DRIVER) $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $(REF_EXE)

#----------------------------
# compila, corre prueba simple y enviar log
$(REF_MODEL:=_exe):
	./$(REF_EXE) | tee $(LOGS)/$(@:_sim_%=%)_$(shell date +%d_%H%__MS_).log

###################################################################
# parte para berkeley testfloat
all_berkeley_testfloat: build_berkeley_testfloat testfloat_gen \
						testfloat_replay testfloat_check 

build_berkeley_testfloat: | $(SF_LIBRARY_A)
	$(MAKE) -C $(TF_BUILD) SPECIALIZE_TYPE=RISCV

#----------------------------
# Generar vectores con tf_gen en vectors/, uno por op
# gen_vectors/ guardar/respaldar vectores
testfloat_gen: _mkdir_folders
	for op in $(TF_OPS); do \
		echo ">> $(VECTORS)/$$op.tf"; \
		$(TF_GEN) -rnear_even $$op > $(VECTORS)/$$op.tf; \
	done

#----------------------------
# Compilar tf_replayer (reusa reference_model.o ya producido antes)
# produce el ejecutable standalone_tests/bin/tf_replay
testfloat_replay: $(REF_OBJ)
	$(CC) $(CFLAGS) $(TF_REPLAY_C) $(REF_OBJ) $(SF_LIBRARY_A) \
		$(INCLUDES) -o $(TF_REPLAY_EXE)
# Auditar reference_model contra testfloat mediante un piep
# usa tf_gen | tf_ver
testfloat_check:
	for op in $(TF_OPS); do \
		echo "auditando $$op "; \
		$(TF_GEN) -rnear_even $$op | $(TF_REPLAY_EXE) $$op \
		| $(TF_VER) -rnear_even $$op | tee -a $(LOGS)/$(@)_$(shell date +%d_%H_%M_%S).log; \
	done

###################################################################

clean:
	rm -rf $(BIN) $(BUILD) $(LOGS)

clean_softfloat_build:
	rm -rf $(SF_BUILD)/*.o $(SF_BUILD)/*.a

clean_testfloat_build:
	rm -rf $(VECTORS)/*.tf 

clean_all: clean clean_softfloat_build

help:
	echo "TODO HELP FUNCTION"
.PHONY: all \
		_mkdir_folders \
		_echo_vars \
		all_berkeley_softfloat \
		build_berkeley_softfloat \
		$(REF_MODEL:=_object) \
		$(REF_DRIVER) \
		$(REF_MODEL:=_exe) \
		build_berkeley_testfloat \
		testfloat_gen \
		testfloat_replay \
		testfloat_check \
		clean \
		clean_softfloat_build \
		clean_testfloat_build \
		clean_all \
		help