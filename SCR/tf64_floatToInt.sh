# 0 -rnear_even      --Test only rounding to nearest/even.
# 1 -rminMag         --Test only rounding to minimum magnitude (toward zero).
# 2 -rmin            --Test only rounding to minimum (down).
# 3 -rmax            --Test only rounding to maximum (up).
# 4 -rnear_maxMag    --Test only rounding to nearest/maximum magnitude
#                        (nearest/away).


TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_to_ui32_r_minMag -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 0 1 "$2" "$3" "$4;}' | RND=0 ./obj_dir/Vtb_floatToInt
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_to_ui64_r_minMag -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 0 0 "$2" "$3" "$4;}' | RND=0 ./obj_dir/Vtb_floatToInt
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_to_i32_r_minMag -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 1 1 "$2" "$3" "$4;}' |  RND=0 ./obj_dir/Vtb_floatToInt
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_to_i64_r_minMag -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 1 0 "$2" "$3" "$4;}' |  RND=0 ./obj_dir/Vtb_floatToInt
