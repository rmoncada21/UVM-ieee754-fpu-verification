_test_target:
	echo $@

_testbench_sim:
	./testbench_sim \
	-l ../logs/sim/testbench_sim.log \
	| tee ../logs/tests/testbench_sim_$(shell date +%d_%H%_M%S).log

_sim_fpu_base_test:
	./testbench_sim \
	+UVM_TESTNAME=$(@:_sim_%=%) \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+nbt_random_seed=auto \
	-l ../logs/sim/$(@:_sim_%=%).log \
	| tee ../logs/tests/$(@:_sim_%=%)_$(shell date +%d_%H%_M%S).log

_sim_fpu_NOMBRE_test:
	./testbench_sim \
	+UVM_TESTNAME=$(@:_sim_%=%) \
	+UVM_VERBOSITY=$(VERBOSITY) \
	+nbt_random_seed=auto \
	-l ../logs/sim/$(@:_sim_%=%).log \
	| tee ../logs/tests/$(@:_sim_%=%)_$(shell date +%d_%H%_M%S).log \