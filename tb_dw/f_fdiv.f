-cc 
-Wall 
-Wno-DECLFILENAME
-DFORCE_DW_NAN_BEHAVIOR
-DFORCE_DW_DIV_BEHAVIOR
--top-module tb_fdiv
--exe
--assert
--clk clk
-I../rtl
-I../tb
-I../sim_ver
../rtl/R5FP_int_div_sqrt.v
../rtl/R5FP_div.v
../rtl/R5FP_util.v
../rtl/R5FP_postproc.v
../tb_dw/tb_fdiv.v
../tb_dw/sim_fdiv.cpp

