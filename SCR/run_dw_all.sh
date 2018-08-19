verilator -f ../tb_dw/f_fadd.f
makeV tb_fp_add
source ../SCR/dw_fadd.sh

verilator -f ../tb_dw/f_fmul.f
makeV tb_fp_mul
source ../SCR/dw_fmul.sh

verilator -f ../tb_dw/f_fsqrt.f
makeV tb_fsqrt
source ../SCR/dw_fsqrt.sh

verilator -f ../tb_dw/f_fdiv.f
makeV tb_fdiv
source ../SCR/dw_fdiv.sh

