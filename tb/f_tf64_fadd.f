-cc 
-Wall 
-Wno-DECLFILENAME
-DFP64=1
--top-module tb_fp_add
--exe
--assert
--clk clk
-I../rtl
-I../tb
../rtl/R5FP_add_mul.v
../rtl/R5FP_util.v
../tb/tb_tf_fadd.v
../tb/sim_fadd.cpp
