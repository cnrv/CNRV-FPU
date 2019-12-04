-cc 
-Wall 
-Wno-DECLFILENAME
-DFP64=1
--top-module tb_floatToInt
--exe
--assert
--clk clk
-I../rtl
-I../tb
-I../sim_ver
../rtl/R5FP_postproc.v
../rtl/R5FP_util.v
../tb/tb_tf_floatToInt.v
../tb/sim_floatToInt.cpp
