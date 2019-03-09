# 0 -rnear_even      --Test only rounding to nearest/even.
# 1 -rminMag         --Test only rounding to minimum magnitude (toward zero).
# 2 -rmin            --Test only rounding to minimum (down).
# 3 -rmax            --Test only rounding to maximum (up).
# 4 -rnear_maxMag    --Test only rounding to nearest/maximum magnitude
#                        (nearest/away).

#TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 1 -tininessafter -rmin         |grep "DUMP:" > tests.dat
#cat tests.dat | RND=3 ./obj_dir/Vtb_fp_add

#TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 1 -tininessafter -rmax         |grep "DUMP:" > tests.dat
#cat tests.dat | RND=3 ./obj_dir/Vtb_fp_add

TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 2 -tininessafter -rnear_even   |grep "DUMP:" | RND=0 ./obj_dir/Vtb_fp_add
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 2 -tininessafter -rminMag      |grep "DUMP:" | RND=1 ./obj_dir/Vtb_fp_add
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 2 -tininessafter -rmin         |grep "DUMP:" | RND=2 ./obj_dir/Vtb_fp_add
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 2 -tininessafter -rmax         |grep "DUMP:" | RND=3 ./obj_dir/Vtb_fp_add
TF_DUMP=1 ../../TestFloat-3e/build/Linux-x86_64-GCC/testsoftfloat f64_add -seed 314 -level 2 -tininessafter -rnear_maxMag |grep "DUMP:" | RND=4 ./obj_dir/Vtb_fp_add

