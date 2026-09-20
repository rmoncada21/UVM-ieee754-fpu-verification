# Incluir componentes del testbench
+incdir+tb_components
+incdir+tb_components/interface
+incdir+tb_components/packages

# ============================================================================
# DUT - RTL de la FPU ieee 754
# ============================================================================

# ---- Modulos de Soporte ----
dut/ALU-FPU-ieee754/fp_unpack/fp_unpack.sv
dut/ALU-FPU-ieee754/Sumador_restador/change_sign.sv
dut/ALU-FPU-ieee754/Sumador_restador/align_exponents.sv
dut/ALU-FPU-ieee754/Sumador_restador/add_sub_mantissas.sv
dut/ALU-FPU-ieee754/Sumador_restador/normalize_result.sv
dut/ALU-FPU-ieee754/Sumador_restador/round.sv
dut/ALU-FPU-ieee754/Sumador_restador/fp_pack.sv


# ---- Modulos de Operacion ----
dut/ALU-FPU-ieee754/Sumador_restador/fp_adder.sv
dut/ALU-FPU-ieee754/Sumador_restador/fp_sub.sv
dut/ALU-FPU-ieee754/multiplicador/fp_mul.sv
dut/ALU-FPU-ieee754/Operaciones_comb/fp_madd.sv
dut/ALU-FPU-ieee754/Operaciones_comb/fp_msub.sv
dut/ALU-FPU-ieee754/Comparadores/fp_feq.sv
dut/ALU-FPU-ieee754/Comparadores/fp_fle.sv
dut/ALU-FPU-ieee754/Comparadores/fp_flt.sv
 
# ---- Top del DUT ----
dut/ALU-FPU-ieee754/ALU_FP/fp_alu.sv

# ============================================================================
# Testbench UVM
# ============================================================================

# Incluir packages
tb_components/packages/fpu_types_pkg.sv
tb_components/packages/fpu_dpic_ref_model_pkg.sv
tb_components/packages/fpu_types_constraints_pkg.sv
tb_components/packages/fpu_env_pkg.sv
tb_components/interface/fpu_if.sv

# Incluir top testbench
testbench.sv
