-cc 
-Wall 
-Wno-DECLFILENAME
-DFP64=1
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
../tb/tb_tf_fdiv.v
../tb/sim_fdiv.cpp

