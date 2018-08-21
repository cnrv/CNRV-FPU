-cc 
-Wall 
-Wno-DECLFILENAME
-DFORCE_DW_NAN_BEHAVIOR
--top-module tb_fp_add
--exe
--assert
--clk clk
-I../rtl
-I../tb
../rtl/R5FP_add_mul.v
../rtl/R5FP_util.v
../tb_dw/tb_fadd.v
../tb_dw/sim_fadd.cpp
