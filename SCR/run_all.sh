verilator -f ../tb/f_tf_fadd.f
makeV tb_fp_add
source ../SCR/tf_add.sh

verilator -f ../tb/f_tf_fmul.f
makeV tb_fp_mul
source ../SCR/tf_mul.sh

verilator -f ../tb/f_tf_fsqrt.f
makeV tb_fsqrt
source ../SCR/tf_sqrt.sh

verilator -f ../tb/f_tf_fdiv.f
makeV tb_fdiv
source ../SCR/tf_div.sh

verilator -f ../tb/f_tf_fmac.f
makeV tb_fp_mac
source ../SCR/tf_mac.sh

verilator -f ../tb/f_tf_roundToInt.f
makeV tb_roundToInt
source ../SCR/tf_roundToInt.sh

verilator -f ../tb/f_tf_floatToInt.f
makeV tb_floatToInt
source ../SCR/tf_floatToInt.sh

verilator -f ../tb/f_tf_intToFloat.f
makeV tb_intToFloat
source ../SCR/tf_intToFloat.sh

