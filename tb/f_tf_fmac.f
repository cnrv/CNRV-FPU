-cc 
-Wall 
-Wno-DECLFILENAME
--top-module tb_fp_mac
--exe
--assert
--clk clk
-I../rtl
-I../tb
../rtl/R5FP_add_mul.v
../rtl/R5FP_util.v
../tb/tb_tf_fmac.v
../tb/sim_fmac.cpp
