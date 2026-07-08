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
$(REPLAYER_EXE): $(REPLAYER_C) $(REF_OBJ) $(SF_LIBRARY_A) | $(REF_BIN)
	$(CC) $(CFLAGS) $(REPLAYER_C)  $(REF_OBJ) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile: $(REPLAYER_EXE)

#----------------------------
# checkeo rápido (1 op, RNE)
replayer_check_fast: $(REPLAYER_EXE) | $(LOGS_REPLAY)
	$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) -rnear_even f32_add \
	  | ./$(REPLAYER_EXE) f32_add rne \
	  | $(TF_VER) -rnear_even -checkNaNs -errors 0 f32_add 2>&1 \
	  | tee $(LOGS_REPLAY)/ver_f32_add_rne_$(FECHA).log

#----------------------------
# Auditar reference_model contra testfloat mediante un pipe
# usa tf_gen | tf_ver
replayer_run_matrix: $(REPLAYER_EXE) | $(LOGS_REPLAY)
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	      | ./$(REPLAYER_EXE) $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_REPLAY)/$@_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
	done; \
	for op in $(OPS_CMP); do \
	  echo -e "\n========== replayer $$op =========="; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op \
	    | ./$< -rnear_even $$op 2>&1 \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	    | tee $(LOGS_REPLAY)/$@_$${op}_rne_$(FECHA).log || exit 1; \
	done

# TODO: Correr para ver resultados
replayer_testfloat_sweep: $(REPLAYER_EXE) | $(REF_CSV)
	for op in $(SWEEP_OPS); do \
	  for par in $(ROUND_MODE_PAIRS); do \
	    ref_r=$${par%%:*}; rm=$${par##*:}; \
	    src=$$op; if [ "$$op" = "f32_mulSub" ]; then src=f32_mulAdd; fi; \
	    echo "== csv $$op $$ref_r =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$src \
	      | ./$(REPLAYER_EXE) --csv $$op $$ref_r \
	      > $(REF_CSV)/$${op}_$${ref_r}.csv || exit 1; \
	  done; \
	done; \
	for op in $(OPS_CMP); do \
	  echo "== csv $$op rne =="; \
	  $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$op \
	    | ./$(REPLAYER_EXE) --csv $$op rne \
	    > $(REF_CSV)/$${op}_rne.csv || exit 1; \
	done


####################################################################################
################### Targets: Reglas de análisis dinámico de código: 
# valgrind  : memcheck, massif, callgrind


#------------------------------------------------------------------------------
#  Valgrind: Replayer
#------------------------------------------------------------------------------
replayer_valgrind_all: replayer_memcheck replayer_massif replayer_callgrind

# replayer_memcheck: $(REPLAYER_EXE) | $(LOGS_VALGRIND)
# 	@echo ""
# 	valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
# 		./$< f32_add rne \
# 		| $(TF_VER) -rnear_even f32_add

replayer_memcheck: $(REPLAYER_EXE) | $(LOGS_VALGRIND)
	@echo ""
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	      | valgrind --tool=memcheck --leak-check=full --error-exitcode=1 \
		  ./$(REPLAYER_EXE) $$rm $$op \
	      | $(TF_VER) $$tf_r -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_VALGRIND)/ver_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
	done

replayer_massif: $(REPLAYER_EXE) | $(LOGS_VALGRIND)
	@echo ""
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	    	| valgrind --tool=massif --error-exitcode=1 \
			--massif-out-file=$(LOGS_VALGRIND)/$@_$${op}_$(FECHA).log \
			./$(REPLAYER_EXE) $$rm $$op \
	    	| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	    	| tee $(LOGS_VALGRIND)/$@_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
	done
	for op in $(OPS_CMP); do \
		echo -e "\n========== replayer $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
  			| valgrind --tool=massif --error-exitcode=1 \
  			--massif-out-file=$(LOGS_VALGRIND)/$@_$$op_$(FECHA).log \
  			./$(REPLAYER_EXE) $$rm $$op \
  			| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
  			| tee -a $(LOGS_VALGRIND)/$@_$${op}_$(FECHA).log || exit 1; \
	done




replayer_callgrind: $(REPLAYER_EXE) | $(LOGS_VALGRIND)
	@echo ""
	for op in $(OPS_ARITH); do \
	  for par in $(ROUND_MODE_PAIR); do \
	    rm=$${par##*:}; \
	    echo "== ver $$op $$rm =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
	      | valgrind --tool=callgrind --error-exitcode=1 \
		  ./$(REPLAYER_EXE) $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_VALGRIND)/ver_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
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
$(REPLAYER_ASAN): FORCE $(SF-LIBRARY_A) | $(REF_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=address $(REF_C) $(REPLAYER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile_asan: $(REPLAYER_ASAN)

replayer_run_asan: $(REPLAYER_ASAN) | $(LOGS_SAN)
	for op in $(OPS_ARITH); do \
	  for pair in $(ROUND_MODE_PAIR); do \
		rm=$${pair##*:}; \
	    echo "== ver $$op $$ref_r =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		  | ./$< $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_SAN)/$@_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
	done; \
		for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
		| tee $(LOGS_SAN)/$@_$${op}_$(FECHA).log || exit 1; \
	done

#### memory
$(REPLAYER_MSAN): FORCE $(SF-LIBRARY_A) | $(REF_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=memory $(REF_C) $(REPLAYER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile_msan: $(REPLAYER_MSAN)

replayer_run_msan: $(REPLAYER_MSAN) | $(LOGS_SAN)
	for op in $(OPS_ARITH); do \
	  for pair in $(ROUND_MODE_PAIR); do \
		rm=$${pair##*:}; \
	    echo "== ver $$op $$ref_r =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		  | ./$< $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_SAN)/$@_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
	done; \
		for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
		| tee $(LOGS_SAN)/$@_$${op}_$(FECHA).log || exit 1; \
	done


#### undefined
$(REPLAYER_UBSAN): FORCE $(SF-LIBRARY_A) | $(REF_BIN)
	$(CLANG) $(CLFLAGS) -fsanitize=undefined $(REF_C) $(REPLAYER_C) $(SF_LIBRARY_A) $(INCLUDES) -o $@

replayer_compile_ubsan: $(REPLAYER_UBSAN)

replayer_run_ubsan: $(REPLAYER_UBSAN) | $(LOGS_SAN)
	for op in $(OPS_ARITH); do \
	  for pair in $(ROUND_MODE_PAIR); do \
		rm=$${pair##*:}; \
	    echo "== ver $$op $$ref_r =="; \
	    $(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		  | ./$< $$rm $$op \
	      | $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
	      | tee $(LOGS_SAN)/$@_$${op}_$${rm/-/}_$(FECHA).log || exit 1; \
	  done; \
	done; \
		for op in $(OPS_CMP); do \
		echo -e "\n========== runner $$op =========="; \
		$(TF_GEN) -level $(TF_LEVEL) -seed $(TF_SEED) $$rm $$op \
		|	./$< $$rm $$op \
		| $(TF_VER) $$rm -checkNaNs -errors 0 $$op 2>&1 \
		| tee $(LOGS_SAN)/$@_$${op}_$(FECHA).log || exit 1; \
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
	all_valgrind_replayer \
	replayer_memcheck \
	replayer_massif \
	replayer_callgrind \
	all_sanitizers_replayer \
	replayer_compile_asan \
	replayer_run_asan