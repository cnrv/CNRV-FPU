verilator -f ../tb/f_tf64_fadd.f
makeV tb_fp_add
source ../SCR/tf64_add.sh

verilator -f ../tb/f_tf64_fmul.f
makeV tb_fp_mul
source ../SCR/tf64_mul.sh

verilator -f ../tb/f_tf64_fsqrt.f
makeV tb_fsqrt
source ../SCR/tf64_sqrt.sh

verilator -f ../tb/f_tf64_fdiv.f
makeV tb_fdiv
source ../SCR/tf64_div.sh

verilator -f ../tb/f_tf64_fmac.f
makeV tb_fp_mac
source ../SCR/tf64_mac.sh

verilator -f ../tb/f_tf64_roundToInt.f
makeV tb_roundToInt
source ../SCR/tf64_roundToInt.sh

verilator -f ../tb/f_tf64_floatToInt.f
makeV tb_floatToInt
source ../SCR/tf64_floatToInt.sh

verilator -f ../tb/f_tf64_intToFloat.f
makeV tb_intToFloat
source ../SCR/tf64_intToFloat.sh

