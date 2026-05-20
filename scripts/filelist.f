# Incluir componentes del testbench
+incdir+tb_components
+incdir+tb_components/interface
+incdir+tb_components/packages

# ============================================================================
 
# ---- Modulos de soporte / hoja ----
dut/ALU-FPU-ieee754/fp_unpack/fp_unpack.sv
dut/ALU-FPU-ieee754/Operaciones_comb/change_sign.sv
dut/ALU-FPU-ieee754/Operaciones_comb/align_exponents.sv
dut/ALU-FPU-ieee754/Operaciones_comb/add_sub_mantissas.sv
dut/ALU-FPU-ieee754/Operaciones_comb/normalize_result.sv
dut/ALU-FPU-ieee754/Operaciones_comb/round.sv
dut/ALU-FPU-ieee754/fp_unpack/fp_pack.sv
 
# ---- Modulos de operacion ----
dut/ALU-FPU-ieee754/Sumador_restador/fp_adder.sv
dut/ALU-FPU-ieee754/Sumador_restador/fp_sub.sv
dut/ALU-FPU-ieee754/multiplicador/fp_mul.sv
dut/ALU-FPU-ieee754/Sumador_restador/fp_madd.sv
dut/ALU-FPU-ieee754/Sumador_restador/fp_msub.sv
dut/ALU-FPU-ieee754/Comparadores/fp_feq.sv
dut/ALU-FPU-ieee754/Comparadores/fp_flt.sv
dut/ALU-FPU-ieee754/Comparadores/fp_fle.sv
 
# ---- Top del DUT ----
dut/ALU-FPU-ieee754/ALU_FP/fp_alu.sv


# Incluir packages
tb_components/packages/fpu_pkg.sv
tb_components/packages/fpu_env_pkg.sv
tb_components/interface/fpu_if.sv

# Incluir top testbench
testbench.sv
