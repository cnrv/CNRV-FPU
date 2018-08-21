-cc 
-DFORCE_DW_NAN_BEHAVIOR
-DFORCE_DW_MULT_BEHAVIOR
-Wall 
-Wno-DECLFILENAME
--top-module tb_fp_mul
--exe
--assert
--clk clk
-I../rtl
-I../tb
../rtl/R5FP_add_mul.v
../rtl/R5FP_util.v
../tb_dw/tb_fmul.v
../tb_dw/sim_fmul.cpp
