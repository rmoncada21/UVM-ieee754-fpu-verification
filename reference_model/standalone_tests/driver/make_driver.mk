# include make_common.mk

####################################################################################
################### Targets: compilación y ejecución con gcc

#------------------------------------------------------------------------------
# Compilar y ejecutar: Driver
#------------------------------------------------------------------------------
all_driver: driver_run driver_valgrind_all driver_sanitizers_all

#----------------------------
# enlaza objeto y compila simple_driver
$(DRIVER_EXE): $(DRIVER_MAIN_C) $(DRIVER_C) $(DRIVER_CASES_C) $(REF_OBJ) | $(DRV_BIN)
	$(CC) $(CFLAGS) $(DRIVER_MAIN_C) $(DRIVER_C) $(DRIVER_CASES_C) $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $@

driver_compile: $(DRIVER_EXE)

#--------------------------
driver_run: $(DRIVER_EXE) | $(LOGS_DRV_C)
	./$(DRIVER_EXE) 2>&1 | tee $(LOGS_DRV_C)/$@.log


####################################################################################
################### Targets: Reglas de análisis dinámico de código
# valgrind  : memcheck, massif, callgrind

#------------------------------------------------------------------------------
#  Valgrind: Driver
#------------------------------------------------------------------------------
driver_valgrind_all: driver_memcheck driver_massif driver_callgrind

driver_memcheck: $(DRIVER_EXE) | $(LOGS_DRV_VAL_ME)
	@echo ""
	valgrind --tool=memcheck \
		./$< 2>&1 \
		| tee $(LOGS_DRV_VAL_ME)/$@.log


driver_massif: $(DRIVER_EXE) | $(LOGS_DRV_VAL_MA)
	@echo ""
	valgrind --tool=massif --error-exitcode=1 \
		--massif-out-file=$(LOGS_DRV_VAL_MA)/$@.out \
		./$< 2>&1 \
		| tee $(LOGS_DRV_VAL_MA)/$@.log

driver_callgrind: $(DRIVER_EXE) | $(LOGS_DRV_VAL_CA)
	@echo ""
	valgrind --tool=callgrind \
		--callgrind-out-file=$(LOGS_DRV_VAL_CA)/$@.out \
		./$< 2>&1 \
		| tee $(LOGS_DRV_VAL_CA)/$@.log


####################################################################################
#################### Clang Sanitizers
# sanitizers: addres, memory, undefined

#------------------------------------------------------------------------------
# Sanitizers: Driver
#------------------------------------------------------------------------------
# TODO: agregar reglas a all_driver_sanitizers
driver_sanitizers_all: driver_run_asan driver_run_msan driver_run_ubsan

#### address
$(DRIVER_ASAN): FORCE $(SF_LIBRARY_A) | $(DRV_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=address $(REF_OBJ) $(DRIVER_MAIN_C) $(DRIVER_C) $(DRIVER_CASES_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

driver_compile_asan: $(DRIVER_ASAN)

driver_run_asan: $(DRIVER_ASAN) | $(LOGS_DRV_ASAN)
	ASAN_OPTIONS=log_path=$(LOGS_DRV_ASAN)/$@.out ./$(DRIVER_ASAN) 2>&1 | tee $(LOGS_DRV_ASAN)/$@.log

#### memory
$(DRIVER_MSAN): FORCE $(SF_LIBRARY_A) | $(DRV_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=memory $(REF_OBJ) $(DRIVER_MAIN_C) $(DRIVER_C) $(DRIVER_CASES_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

driver_compile_msan: $(DRIVER_MSAN)

driver_run_msan: $(DRIVER_MSAN) | $(LOGS_DRV_MSAN)
	MSAN_OPTIONS=log_path=$(LOGS_DRV_MSAN)/$@.out ./$(DRIVER_MSAN) 2>&1 | tee $(LOGS_DRV_MSAN)/$@.log

#### undefined
$(DRIVER_USAN): FORCE $(SF_LIBRARY_A) | $(DRV_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=undefined $(REF_OBJ) $(DRIVER_MAIN_C) $(DRIVER_C) $(DRIVER_CASES_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

driver_compile_ubsan: $(DRIVER_USAN)

driver_run_ubsan: $(DRIVER_USAN) | $(LOGS_DRV_UBSAN)
	UBSAN_OPTIONS=log_path=$(LOGS_DRV_UBSAN)/$@.out ./$(DRIVER_USAN) 2>&1 | tee $(LOGS_DRV_UBSAN)/$@.log

# TODO: help driver
help_driver:

# TODO: PHONY DRIVER
.PHONY: \
	all_driver \
	driver_compile \
	driver_run \
	driver_valgrind_all \
	driver_memcheck \
	driver_massif \
	driver_callgrind \
	driver_sanitizers_all \
	driver_compile_asan \
	driver_run_asan \
	driver_compile_msan \
	driver_run_msan \
	driver_compile_ubsan \
	driver_run_ubsan