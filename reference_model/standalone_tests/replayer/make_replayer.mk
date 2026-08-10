# include make_common.mk

####################################################################################
################### Targets: compilación y ejecución con gcc

#------------------------------------------------------------------------------
# Compilar y ejecutar: Replayer
#------------------------------------------------------------------------------
all_replayer: replayer_run_matrix replayer_valgrind_all replayer_sanitizers_all

#----------------------------
# Compilar tf_replayer (usa reference_model.o ya producido antes)
# produce el ejecutable standalone_tests/bin/tf_replay
$(REPLAYER_EXE): $(REPLAYER_MAIN_C) $(REPLAYER_C) $(REF_OBJ) $(SF_LIBRARY_A) | $(REP_BIN)
	$(CC) $(CFLAGS) $(REPLAYER_MAIN_C) $(REPLAYER_C)  $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile: $(REPLAYER_EXE)

#----------------------------
# checkeo rápido (1 op, RNE)
replayer_check_fast: $(REPLAYER_EXE) | $(LOGS_REP_C)
	$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) -rnear_even f32_add \
	  | ./$(REPLAYER_EXE) -rnear_even f32_add \
	  | $(TF_VER) -rnear_even -checkNaNs -errors 0 f32_add 2>&1 \
	  | tee $(LOGS_REP_C)/ver_f32_add_rne.log

#----------------------------
# Auditar reference_model contra testfloat mediante un pipe
# usa tf_gen | tf_ver
replayer_run_matrix: $(REPLAYER_EXE) | $(LOGS_REP_C)
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	      | ./$(REPLAYER_EXE) $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_REP_C)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done; \
	for op in $(OPS_CMP); do \
	  rm=-rnear_even; \
	  echo -e "\n========== replayer $$op =========="; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op \
	    | ./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	    | tee $(LOGS_REP_C)/$@_$${op}_$${rm/-/}.log || exit 1; \
	done

# TODO: Correr para ver resultados
# TODO: Corregir 
replayer_testfloat_sweep: $(REPLAYER_EXE) | $(REF_CSV)
	for op in $(SWEEP_OPS); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    ref_r=$${par%%:*}; rm=$${par##*:}; \
	    src=$$op; if [ "$$op" = "f32_mulSub" ]; then src=f32_mulAdd; fi; \
	    echo "== csv $$op $$ref_r =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$src \
	      | ./$(REPLAYER_EXE) $$rm $$op --csv \
	      > $(REF_CSV)/$${op}_$${ref_r}.csv || exit 1; \
	  done; \
	done; \
	for op in $(OPS_CMP); do \
	  echo "== csv $$op rne =="; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op \
	    | ./$(REPLAYER_EXE) -rnear_even $$op --csv \
	    > $(REF_CSV)/$${op}_rne.csv || exit 1; \
	done


####################################################################################
################### Targets: Reglas de análisis dinámico de código: 
# valgrind  : memcheck, massif, callgrind


#------------------------------------------------------------------------------
#  Valgrind: Replayer
#------------------------------------------------------------------------------
replayer_valgrind_all: replayer_memcheck replayer_massif replayer_callgrind

# replayer_memcheck: $(REPLAYER_EXE) | $(LOGS_REP_VAL)
# 	@echo ""
# 	valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
# 		./$< f32_add rne \
# 		| $(TF_VER) -rnear_even f32_add

replayer_memcheck: $(REPLAYER_EXE) | $(LOGS_REP_VAL_ME)
	@echo ""
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	      | valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
		  --log-file=$(LOGS_REP_VAL_ME)/$@_$${op}_$${rm/-/}.out \
		  ./$(REPLAYER_EXE) $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_REP_VAL_ME)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done

replayer_massif: $(REPLAYER_EXE) | $(LOGS_REP_VAL_MA)
	@echo ""
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	    	| valgrind --tool=massif --error-exitcode=1 \
			--massif-out-file=$(LOGS_REP_VAL_MA)/$@_$${op}_$${rm/-/}.out \
			--log-file=$(LOGS_REP_VAL_MA)/$@_$${op}_$${rm/-/}_valgrind.out \
			./$(REPLAYER_EXE) $$rm $$op \
	    	| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	    	| tee $(LOGS_REP_VAL_MA)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done
	for op in $(OPS_CMP); do \
		rm=-rnear_even; \
		echo -e "\n========== replayer $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
  			| valgrind --tool=massif --error-exitcode=1 \
  			--massif-out-file=$(LOGS_REP_VAL_MA)/$@_$${op}_$${rm/-/}.out \
  			--log-file=$(LOGS_REP_VAL_MA)/$@_$${op}_$${rm/-/}_valgrind.out \
  			./$(REPLAYER_EXE) $$rm $$op \
  			| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
  			| tee -a $(LOGS_REP_VAL_MA)/$@_$${op}_$${rm/-/}.log || exit 1; \
	done




# replayer_callgrind: $(REPLAYER_EXE) | $(LOGS_REP_VAL)
# 	@echo ""
# 	for op in $(OPS_ARITH); do \
# 	  for par in $(ROUND_MODE_PAIR); do \
# 	    rm=$${par##*:}; \
# 	    echo "== ver $$op $$rm =="; \
# 	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
# 	      | valgrind --tool=callgrind --error-exitcode=1 \
# 		  ./$(REPLAYER_EXE) $$rm $$op \
# 	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
# 	      | tee $(LOGS_REP_VAL)/ver_$${op}_$${rm/-/}.log || exit 1; \
# 	  done; \
# 	done

#### callgrind
# TODO: agregar --log-file al valgrind y
replayer_callgrind: $(REPLAYER_EXE) | $(LOGS_REP_VAL_CA)
	for op in $(OPS_ARITH); do \
		for pair in $(ROUND_MODE_PAIR); do \
			rm=$${pair##*:}; \
			echo -e "\n========== replayer $$rm $$op =========="; \
			$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
			| valgrind --tool=callgrind --error-exitcode=1 \
				--callgrind-out-file=$(LOGS_REP_VAL_CA)/$@_$${op}_$${rm/-/}.out \
				./$< $$rm $$op 2>&1 \
			| tee $(LOGS_REP_VAL_CA)/$@_$${op}_$${rm/-/}.log || exit 1; \
		done ; \
	done ; \
	for op in $(OPS_CMP); do \
		rm=-rnear_even; \
		echo -e "\n========== replayer $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		| valgrind --tool=callgrind --error-exitcode=1 \
			--callgrind-out-file=$(LOGS_REP_VAL_CA)/$@_$${op}_$${rm/-/}.out \
			./$< $$rm $$op 2>&1 \
		| tee $(LOGS_REP_VAL_CA)/$@_$${op}_$${rm/-/}.log || exit 1; \
	done
####################################################################################
#################### Clang Sanitizers
# sanitizers: addres, memory, undefined

#------------------------------------------------------------------------------
# Sanitizers: Replayer
#------------------------------------------------------------------------------

# TODO:
replayer_sanitizers_all: replayer_run_asan replayer_run_msan replayer_run_ubsan

#### address
$(REPLAYER_ASAN): FORCE $(REPLAYER_MAIN_C) $(SF_LIBRARY_A) | $(REP_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=address $(REPLAYER_MAIN_C) $(REF_OBJ) $(REPLAYER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile_asan: $(REPLAYER_ASAN)

replayer_run_asan: $(REPLAYER_ASAN) | $(LOGS_REP_ASAN)
	for op in $(OPS_ARITH); do \
	  for pair in $(ROUND_MODE_PAIR); do \
		rm=$${pair##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		  | ASAN_OPTIONS=log_path=$(LOGS_REP_ASAN)/$@_$${op}_$${rm/-/}.out ./$< $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_REP_ASAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done; \
		for op in $(OPS_CMP); do \
		rm=-rnear_even; \
		echo -e "\n========== replayer $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	ASAN_OPTIONS=log_path=$(LOGS_REP_ASAN)/$@_$${op}_$${rm/-/}.out ./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
		| tee $(LOGS_REP_ASAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
	done

#### memory
$(REPLAYER_MSAN): FORCE $(REPLAYER_MAIN_C) $(SF_LIBRARY_A) | $(REP_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=memory $(REPLAYER_MAIN_C) $(REF_OBJ) $(REPLAYER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile_msan: $(REPLAYER_MSAN)

replayer_run_msan: $(REPLAYER_MSAN) | $(LOGS_REP_MSAN)
	for op in $(OPS_ARITH); do \
	  for pair in $(ROUND_MODE_PAIR); do \
		rm=$${pair##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		  | MSAN_OPTIONS=log_path=$(LOGS_REP_MSAN)/$@_$${op}_$${rm/-/}.out ./$< $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_REP_MSAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done; \
		for op in $(OPS_CMP); do \
		rm=-rnear_even; \
		echo -e "\n========== replayer $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	MSAN_OPTIONS=log_path=$(LOGS_REP_MSAN)/$@_$${op}_$${rm/-/}.out ./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
		| tee $(LOGS_REP_MSAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
	done


#### undefined
$(REPLAYER_UBSAN): FORCE $(REPLAYER_MAIN_C) $(SF_LIBRARY_A) | $(REP_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=undefined $(REPLAYER_MAIN_C)  $(REF_OBJ) $(REPLAYER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile_ubsan: $(REPLAYER_UBSAN)

replayer_run_ubsan: $(REPLAYER_UBSAN) | $(LOGS_REP_UBSAN)
	for op in $(OPS_ARITH); do \
	  for pair in $(ROUND_MODE_PAIR); do \
		rm=$${pair##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		  | UBSAN_OPTIONS=log_path=$(LOGS_REP_UBSAN)/$@_$${op}_$${rm/-/}.out ./$< $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_REP_UBSAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
	  done; \
	done; \
		for op in $(OPS_CMP); do \
		rm=-rnear_even; \
		echo -e "\n========== replayer $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	UBSAN_OPTIONS=log_path=$(LOGS_REP_UBSAN)/$@_$${op}_$${rm/-/}.out ./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
		| tee $(LOGS_REP_UBSAN)/$@_$${op}_$${rm/-/}.log || exit 1; \
	done

# TODO: help replayer
help_replayer:

# TODO: PHONY replayer
.PHONY: \
	all_replayer \
	replayer_compile \
	replayer_check_fast \
	replayer_run_matrix \
	replayer_testfloat_sweep \
	replayer_valgrind_all \
	replayer_memcheck \
	replayer_massif \
	replayer_callgrind \
	replayer_sanitizers_all \
	replayer_compile_asan \
	replayer_run_asan \
	replayer_compile_msan \
	replayer_run_msan \
	replayer_compile_ubsan \
	replayer_run_ubsan