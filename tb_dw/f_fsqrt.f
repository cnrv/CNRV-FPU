-cc 
-Wall 
-Wno-DECLFILENAME
-DFORCE_DW_SQRT_BEHAVIOR
--top-module tb_fsqrt
--exe
--assert
--clk clk
-I../rtl
-I../tb
-I../sim_ver
../rtl/R5FP_int_div_sqrt.v
../rtl/R5FP_sqrt.v
../rtl/R5FP_util.v
../tb_dw/tb_fsqrt.v
../tb_dw/sim_fsqrt.cpp
