-cc 
-Wall 
-Wno-DECLFILENAME
--top-module tb_sqrt
--exe
--assert
--clk clk
-I../rtl
-I../tb
../rtl/R5FP_int_div_sqrt.v
../tb/tb_sqrt.v
../tb/sim_sqrt.cpp
