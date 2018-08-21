
/*============================================================================

This C source file is part of TestFloat, Release 3e, a package of programs for
testing the correctness of floating-point arithmetic complying with the IEEE
Standard for Floating-Point, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014, 2017 The Regents of the University of
California.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

#include <stdint.h>
#include "platform.h"
#include "softfloat.h"
#include "genCases.h"
#include "verCases.h"
#include "writeCase.h"
#include "testLoops.h"
#include <stdlib.h>
#include <fenv.h>
#include <math.h>

#pragma STDC FENV_ACCESS ON

void
 test_abcz_f32(
     float32_t trueFunction( float32_t, float32_t, float32_t ),
     float32_t subjFunction( float32_t, float32_t, float32_t )
 )
{
    int count;
    float32_t trueZ;
    uint_fast8_t trueFlags;
    float32_t subjZ;
    uint_fast8_t subjFlags;

    genCases_f32_abc_init();
    genCases_writeTestsTotal( testLoops_forever );
    verCases_errorCount = 0;
    verCases_tenThousandsCount = 0;
    count = 10000;
    int dumpit=(getenv("TF_DUMP")!=NULL);
    if(dumpit) {
        int rnd=(getenv("RND")==NULL)? 0 : atoi(getenv("RND"));
        if(rnd==0) fesetround(FE_TONEAREST);
        if(rnd==1) fesetround(FE_TOWARDZERO);
        if(rnd==2) fesetround(FE_DOWNWARD);
        if(rnd==3) fesetround(FE_UPWARD);
    }
    while ( ! genCases_done || testLoops_forever ) {
        genCases_f32_abc_next();
        *testLoops_trueFlagsPtr = 0;
        trueZ = trueFunction( genCases_f32_a, genCases_f32_b, genCases_f32_c );
	if(dumpit) {
	    uint32_t *x,*y,*z,*o,f;
	    float *xf,*yf,*zf;
	    float oRef;
	    uint32_t oRefI, fRef;
	    x=(uint32_t*)(&genCases_f32_a);
	    y=(uint32_t*)(&genCases_f32_b);
	    z=(uint32_t*)(&genCases_f32_c);
	    o=(uint32_t*)(&trueZ);
	    f=*(uint32_t*)testLoops_trueFlagsPtr;
	    printf("DUMP: %08x %08x %08x %08x %08x\n", *x, *y, *z, *o, f);

	    //const uint32_t EXP_FIELD=0xFF<<23;
	    //const uint32_t MANT_FIELD=(1<<23)-1;
	    //feclearexcept(FE_ALL_EXCEPT);
	    //xf=(float*)(&genCases_f32_a);
	    //yf=(float*)(&genCases_f32_b);
	    //zf=(float*)(&genCases_f32_c);
	    //oRef=fmaf(*xf, *yf, *zf);
	    //oRefI=*((uint32_t*)(&oRef));
	    //fRef=0;
	    //int resIsNaN=(*o&MANT_FIELD)!=0 && (*o&EXP_FIELD)==EXP_FIELD;
	    //int refIsNaN=(oRefI&MANT_FIELD)!=0 && (oRefI&EXP_FIELD)==EXP_FIELD;
            //if(fetestexcept(FE_INEXACT))  fRef|=softfloat_flag_inexact;
            //if(fetestexcept(FE_INVALID))  fRef|=softfloat_flag_invalid;
            //if(fetestexcept(FE_OVERFLOW)) fRef|=softfloat_flag_overflow;
            //if(fetestexcept(FE_UNDERFLOW))fRef|=softfloat_flag_underflow;
	    //if(refIsNaN) fRef=(fRef&~softfloat_flag_invalid);//do not care invalid
	    //if(resIsNaN)    f=(   f&~softfloat_flag_invalid);//do not care invalid
	    //f=f&~softfloat_flag_infinite;
	    //int pass;
	    //pass=(oRefI==*o || (resIsNaN&&refIsNaN));
	    //if(fRef!=f) pass=0;
	    //if(!pass) {
	    //    printf("ERR: %08x %08x %08x %08x %08x | %08x %08x %d %d\n",
	    //    *x, *y, *z, *o, f, oRefI, fRef, refIsNaN, resIsNaN);
	    //}
	    //else {
	    //    //printf("DUMP: %08x %08x %08x %08x %08x\n", *x, *y, *z, *o, f);
	    //}
	}
        trueFlags = *testLoops_trueFlagsPtr;
        testLoops_subjFlagsFunction();
        subjZ = subjFunction( genCases_f32_a, genCases_f32_b, genCases_f32_c );
        subjFlags = testLoops_subjFlagsFunction();
        --count;
        if ( ! count ) {
            verCases_perTenThousand();
            count = 10000;
        }
        if ( ! f32_same( trueZ, subjZ ) || (trueFlags != subjFlags) ) {
            if (
                   ! verCases_checkNaNs
                && (   f32_isSignalingNaN( genCases_f32_a )
                    || f32_isSignalingNaN( genCases_f32_b )
                    || f32_isSignalingNaN( genCases_f32_c )
                   )
            ) {
                trueFlags |= softfloat_flag_invalid;
            }
            if (
                   verCases_checkNaNs
                || ! f32_isNaN( trueZ )
                || ! f32_isNaN( subjZ )
                || f32_isSignalingNaN( subjZ )
                || (trueFlags != subjFlags)
            ) {
                ++verCases_errorCount;
                verCases_writeErrorFound( 10000 - count );
                writeCase_abc_f32(
                    genCases_f32_a, genCases_f32_b, genCases_f32_c );
                writeCase_z_f32( trueZ, trueFlags, subjZ, subjFlags );
                if ( verCases_errorCount == verCases_maxErrorCount ) break;
            }
        }
    }
    verCases_writeTestsPerformed( 10000 - count );

}

