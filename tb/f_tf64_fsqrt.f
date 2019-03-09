-cc 
-Wall 
-Wno-DECLFILENAME
-DFP64=1
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
../tb/tb_tf_fsqrt.v
../tb/sim_fsqrt.cpp
