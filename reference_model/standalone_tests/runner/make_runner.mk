# include make_common.mk

####################################################################################
################### Targets: compilación y ejecución con gcc

#------------------------------------------------------------------------------
# Compilar y ejecutar: Runner validación cruzada
#------------------------------------------------------------------------------
all_runner: runner_run_matrix runner_valgrind_all runner_sanitizers_all

# #-------------------------
# $(RUNNER_EXE): $(RUNNER_C) $(SF_LIBRARY_A) | $(RUN_BIN)
# 	$(CC) $(CFLAGS) $(RUNNER_C) $(REF_OBJ) $(SF_LIBRARY_A) -I$(SF_INCLUDE) -o $@
#-------------------------
$(RUNNER_EXE): $(RUNNER_MAIN_C) $(RUNNER_C) $(SF_LIBRARY_A) | $(RUN_BIN)
	$(CC) $(CFLAGS) $(RUNNER_MAIN_C) $(RUNNER_C) $(SF_LIBRARY_A) -I$(INCLUDES) -o $@
runner_compile: $(RUNNER_EXE)

RUNNER_TRACE ?= 0          # 0 = silencioso (CI); N = primeros N; all = todos

runner_run_default_case: $(RUNNER_EXE) | $(LOGS_RUN_C)
	$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) -rnear_even f32_mul \
	  | RUNNER_TRACE=$(RUNNER_TRACE) ./$(RUNNER_EXE) -rnear_even f32_mul 2>&1 \
	  | tee $(LOGS_RUN_C)/runner_mul_rne.log

# probar solo con un redondeo y operacion por el momento
# runner_run_default_case: $(RUNNER_EXE) | $(LOGS_RUN_C)
# 	$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) -rnear_even f32_mul \
# 	  | ./$(RUNNER_EXE) -rnear_even f32_mul

# 	  | tee $(LOGS_RUN_C)/runner_mul_rne.log

# CONTINUAR
# OPS_ARITH    = 3 opciones
# ROUND_MODE_PAIR = 5 opciones 3x5=15 tests
# OPS_CMP      = 3 opciones sin redondeo
# 18 tests en total
runner_run_matrix: $(RUNNER_EXE) | $(LOGS_RUN_C) 
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
	    	echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	    	| RUNNER_TRACE=$(RUNNER_TRACE) ./$(RUNNER_EXE) $$rm $$op 2>&1 \
	    	| tee $(LOGS_RUN_C)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op \
		| RUNNER_TRACE=$(RUNNER_TRACE) ./$(RUNNER_EXE) -rnear_even $$op 2>&1 \
	    | tee $(LOGS_RUN_C)/$@_$${op}_rne.log || exit 1; \
	done

#------------------------------------------------------------------------------
#  Valgrind: Runner
#------------------------------------------------------------------------------
# TODO:
# RANDOM_NUM := $(shell shuf -i 1-100 -n 1)
runner_valgrind_all: runner_memcheck runner_massif runner_callgrind

#### memcheck
# TODO: agregar --log-file al valgrind y
runner_memcheck: $(RUNNER_EXE) | $(LOGS_RUN_VAL)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			| valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
				./$< $$rm $$op \
			| tee $(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		| valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
			./$< $$rm $$op \
		| tee $(LOGS_RUN_VAL)/$@_$${op}.log || exit 1; \
	done

#### massif
# TODO: agregar --log-file al valgrind y
# | tee $(LOGS_RUN_VAL)/$@_$${rm/-/}_$${op}.log || exit 1;
runner_massif: $(RUNNER_EXE) | $(LOGS_RUN_VAL)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			| valgrind --tool=massif --error-exitcode=1 \
				--massif-out-file=$(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log \
				./$< $$rm $$op \
			| tee $(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		| valgrind --tool=massif --error-exitcode=1 \
			--massif-out-file=$(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log \
			./$< $$rm $$op \
		| tee $(LOGS_RUN_VAL)/$@_$${op}.log || exit 1; \
	done

#### callgrind
# TODO: agregar --log-file al valgrind y
runner_callgrind: $(RUNNER_EXE) | $(LOGS_RUN_VAL)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			| valgrind --tool=callgrind --error-exitcode=1 \
				--callgrind-out-file=$(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log \
				./$< $$rm $$op \
			| tee $(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		| valgrind --tool=callgrind --error-exitcode=1 \
			--callgrind-out-file=$(LOGS_RUN_VAL)/$@_$${op}_$${rm/-/}.log \
			./$< $$rm $$op \
		| tee $(LOGS_RUN_VAL)/$@_$${op}.log || exit 1; \
	done

####################################################################################
#################### Clang Sanitizers
# sanitizers: addres, memory, undefined

#------------------------------------------------------------------------------
# Sanitizers: Runner
#------------------------------------------------------------------------------
# TODO:
runner_sanitizers_all: runner_run_asan runner_run_msan runner_run_ubsan

#### address
$(RUNNER_ASAN): FORCE $(SF_LIBRARY_A) | $(RUN_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=address $(RUNNER_MAIN_C) $(RUNNER_C) $(SF_LIBRARY_A) -I$(INCLUDES) -o $@

runner_compile_asan: $(RUNNER_ASAN)

runner_run_asan: $(RUNNER_ASAN) | $(LOGS_RUN_SAN)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			|	./$< $$rm $$op \
			| tee $(LOGS_RUN_SAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	./$< $$rm $$op \
		| tee $(LOGS_RUN_SAN)/$@_$${op}.log || exit 1; \
	done

#### memory
$(RUNNER_MSAN): FORCE $(SF_LIBRARY_A) | $(RUN_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=memory $(RUNNER_MAIN_C) $(RUNNER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

runner_compile_msan: $(RUNNER_MSAN)

runner_run_msan: $(RUNNER_MSAN) | $(LOGS_RUN_SAN)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			|	./$< $$rm $$op \
			| tee $(LOGS_RUN_SAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	./$< $$rm $$op \
		| tee $(LOGS_RUN_SAN)/$@_$${op}.log || exit 1; \
	done


#### undefined
$(RUNNER_UBSAN): FORCE $(SF_LIBRARY_A) | $(RUN_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=undefined $(RUNNER_MAIN_C) $(RUNNER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

runner_compile_ubsan: $(RUNNER_UBSAN)

runner_run_ubsan: $(RUNNER_UBSAN) | $(LOGS_RUN_SAN)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== runner $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			|	./$< $$rm $$op \
			| tee $(LOGS_RUN_SAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	./$< $$rm $$op \
		| tee $(LOGS_RUN_SAN)/$@_$${op}.log || exit 1; \
	done

# TODO: help runner
help_runner:


# TODO: PHONY runner
.PHONY: \
	all_runner \
	runner_compile \
	runner_run_default_case \
	runner_run_matrix \
	all_valgrind_runner \
	runner_memcheck \
	runner_massif \
	runner_callgrind \
	all_sanitizers_runner \
	runner_compile_asan \
	runner_run_asan \
	runner_compile_msan \
	runner_run_msan \
	runner_compile_ubsan \
	runner_run_ubsan