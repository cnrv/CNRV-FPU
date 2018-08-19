-cc 
-Wall 
-Wno-DECLFILENAME
--top-module tb_div
--exe
--assert
--clk clk
-I../rtl
-I../tb
../rtl/R5FP_int_div_sqrt.v
../tb/tb_div.v
../tb/sim_div.cpp
