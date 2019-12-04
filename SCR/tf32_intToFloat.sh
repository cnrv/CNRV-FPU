# 0 -rnear_even      --Test only rounding to nearest/even.
# 1 -rminMag         --Test only rounding to minimum magnitude (toward zero).
# 2 -rmin            --Test only rounding to minimum (down).
# 3 -rmax            --Test only rounding to maximum (up).
# 4 -rnear_maxMag    --Test only rounding to nearest/maximum magnitude
#                        (nearest/away).


TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat ui32_to_f32 -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 0 1 "$2" "$3" "$4;}' | RND=0 ./obj_dir/Vtb_intToFloat
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat ui64_to_f32 -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 0 0 "$2" "$3" "$4;}' | RND=0 ./obj_dir/Vtb_intToFloat
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat i32_to_f32 -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 1 1 "$2" "$3" "$4;}' |  RND=0 ./obj_dir/Vtb_intToFloat
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat i64_to_f32 -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" |gawk '{print $1" 1 0 "$2" "$3" "$4;}' |  RND=0 ./obj_dir/Vtb_intToFloat
