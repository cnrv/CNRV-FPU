
`include "R5FP_inc.vh"

`define DEBUG $display

module R5FP_add #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
    input  [2:0] rnd,
    output reg [7:0] status,
	output [EXP_W+SIG_W:0] z);

wire sign, isNaN, isINF, useA, useB, isZero0, newNaN;
R5FP_add_special_cases #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) sp (
	.a(a), .b(b),
    .sign(sign), .isNaN(isNaN), .newNaN(newNaN), .isINF(isINF), .useA(useA), .useB(useB), .isZero(isZero0));

wire [2:0] GRT;
wire [EXP_W+SIG_W:0] z_tmp;
reg [EXP_W+SIG_W:0] z_tmp2;
wire isZero;
R5FP_add_core #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) add (
	.a(a), .b(b), .GRT(GRT), .isZero(isZero), .z(z_tmp));

reg [6:0] status_tmp;
always @(*) begin
	status_tmp=0;
	status_tmp[`IS_NAN]=isNaN;
	status_tmp[`IS_INF]=isINF;
	status_tmp[`IS_ZERO]=isZero0;
	if(isNaN||isINF) status_tmp[`SIGN]=sign;
	if(useA==0&&useB==0) begin
		status_tmp[`STICKY]=GRT[0];
		status_tmp[`IS_ZERO]=isZero;
	end
	if(isNaN) begin
		z_tmp2[SIG_W-1:0]=({SIG_W{useA}}&a[SIG_W-1:0])|({SIG_W{useB}}&b[SIG_W-1:0]);
		if(newNaN) z_tmp2[0]=1;
	end
	else begin
		if(useA) z_tmp2=a;
		else if(useB) z_tmp2=b;
		else z_tmp2=z_tmp;
	end
end

reg [EXP_W-1:0] zExp_tmp,tailZeroCnt;
always @(*) begin
	tailZeroCnt=0;
	zExp_tmp=z_tmp2[EXP_W-1+SIG_W:SIG_W];
	if(zExp_tmp>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && zExp_tmp<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
		tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-zExp_tmp);
	end
	//$display("Here2 status_tmp:%b z_tmp2:%b isZero0:%b isNaN:%b isINF:%b useA:%b useB:%b zExp_tmp:%b %b %b", status_tmp,z_tmp2,isZero0,isNaN,isINF,useA,useB,zExp_tmp,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),`EXP_DENORMAL_MAX(EXP_W-1));
end
R5FP_postproc #(
        .I_SIG_W(SIG_W+4),
        .SIG_W(SIG_W),
        .EXP_W(EXP_W)) pp (
        .aExp(z_tmp2[EXP_W+SIG_W-1:SIG_W]),
        .aStatus(status_tmp),
        .aSig({2'b01, z_tmp2[SIG_W-1:0], (useA==0&&useB==0)? GRT[2:1] : 2'b00}),
		.tailZeroCnt(tailZeroCnt),
        .rnd(rnd),
		.aSign(z_tmp2[EXP_W+SIG_W]),
        .z(z),
        .status(status));

endmodule

module R5FP_add_special_cases #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
    output  reg sign, isNaN, newNaN, isINF, useA, useB, isZero);

localparam E_MAX=((1<<EXP_W)-1);
    
wire a_s, b_s;
wire [EXP_W-1:0] a_e, b_e;
wire [SIG_W-1:0] a_m, b_m;
assign {a_s,a_e,a_m}=a; 
assign {b_s,b_e,b_m}=b; 

always@(*)   begin
	sign=0;
	isNaN=0;
	isINF=0;
	useB=(a_e==0 && a_m==0);
	useA=(b_e==0 && b_m==0);
	newNaN=0;
	isZero=useA&&useB;
	//if a is NaN or b is NaN return NaN 
	if ((a_e==E_MAX && a_m != 0)) begin
		isNaN = 1;
		useA=1;
	end
	if ((b_e==E_MAX && b_m != 0)) begin
		isNaN = 1;
		useB=1;
	end 
	//if a and b is +inf and -inf, return NaN
	else if (a_e==E_MAX && b_e==E_MAX && a_s!=b_s) begin
		isNaN = 1;
		newNaN = 1;
	end 
	//if a is inf return inf
	else if (a_e==E_MAX) begin
		isINF = 1;
		sign=a_s;
	end 
	//if b is inf return inf
	else if (b_e==E_MAX) begin
		isINF = 1;
		sign=b_s;
	end
end
endmodule

module R5FP_add_core #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
	output reg [2:0] GRT,
	output reg isZero,
	output [EXP_W+SIG_W:0] z);

reg zSign,sticky;
reg [EXP_W-1:0] zExp;
reg [SIG_W-1:0] zSig;
assign z={zSign,zExp,zSig};

wire aSign=a[EXP_W+SIG_W];
wire bSign=b[EXP_W+SIG_W];
wire [SIG_W+3:0] aSig={2'b01,a[SIG_W-1:0],2'b0};
wire [SIG_W+3:0] bSig={2'b01,b[SIG_W-1:0],2'b0};
wire [EXP_W-1:0] aExp=a[EXP_W+SIG_W-1:SIG_W];
wire [EXP_W-1:0] bExp=b[EXP_W+SIG_W-1:SIG_W];

parameter width = SIG_W+1;
parameter addr_width = $clog2(width);
`include "DW_lza_function.inc"

function [SIG_W+4:0] shiftRightJam( input [SIG_W+3:0] smallerSig, 
	  input [EXP_W:0] shiftCnt, input extraShift);
    reg [SIG_W+3:0] res, mask;
	mask=({SIG_W+4{1'b1}}<<shiftCnt);
	if(extraShift) mask=mask<<1;
	res=smallerSig>>shiftCnt;
	if(extraShift) res=res>>1;
	shiftRightJam={res,(smallerSig&~mask)!=0};
endfunction

reg signed [EXP_W:0] expDiff;
reg signed [EXP_W:0] lzCount,shiftCnt;
reg extraShift, sameSign;
reg [1:0] opType;
reg [SIG_W+3:0] largerSig, smallerSig, smallerSigSh, smallerSigSh1;
reg [SIG_W+3:0] zSigExt;
parameter [1:0] NORMAL_ADD=0;
parameter [1:0] NORMAL_SUB=1;
parameter [1:0] SPECIAL_SUB=2;

always @(*) begin
	lzCount=0;
	isZero=0;
	extraShift=1'b0;
	shiftCnt=0;
	expDiff=aExp-bExp;
	sameSign=(aSign==bSign);
	opType=sameSign? NORMAL_ADD : NORMAL_SUB;
	if(expDiff==0) begin
		zExp=aExp;
		if(aSig>bSig) begin
			largerSig=aSig;
			smallerSig=bSig;
			zSign=aSign;
		end
		else begin
			largerSig=bSig;
			smallerSig=aSig;
			zSign=bSign;
		end
	end
	else if(expDiff>0) begin //a is bigger
		zExp=aExp;
		zSign=aSign;
		largerSig=aSig;
		smallerSig=bSig;
		shiftCnt=expDiff;
	end
	else begin //b is bigger
		zExp=bExp;
		zSign=bSign;
		largerSig=bSig;
		smallerSig=aSig;
		shiftCnt=~expDiff;
		extraShift=1'b1;
	end
	if(!sameSign) begin
		smallerSigSh1=(expDiff==0)? smallerSig : smallerSig>>1;
		lzCount=DWF_lza(largerSig[SIG_W+2:2], smallerSigSh1[SIG_W+2:2]);
		if(expDiff==1||expDiff==-1||expDiff==0) opType=SPECIAL_SUB;
	end

	{smallerSigSh,sticky}=shiftRightJam(smallerSig, shiftCnt, extraShift);
	//`DEBUG("Here3.1 a:%b b:%b smallerSig:%b (%b) smallerSigSh:%b sticky:%b",a,b,smallerSig,shiftCnt,smallerSigSh,sticky);
	if(sameSign) zSigExt=largerSig+smallerSigSh;
	else         zSigExt=largerSig-smallerSigSh-sticky;

	if(opType==NORMAL_ADD) begin
		if(zSigExt[SIG_W+3]==1'b1) begin
			sticky=sticky|zSigExt[0];
			zSigExt=zSigExt>>1;
			zExp=zExp+1;
		end
	end
	else if(opType==NORMAL_SUB) begin
		if(zSigExt[SIG_W+2]==1'b0) begin
			zSigExt=zSigExt<<1;
			zExp=zExp-1;
		end
	end
	else if(zSigExt==0) begin
		zExp=0;
		isZero=1;
	end
	else begin
		zSigExt=zSigExt<<lzCount;
		zExp=zExp-lzCount;
		if(zSigExt[SIG_W+2]==1'b0) begin
			zSigExt=zSigExt<<1;
			zExp=zExp-1;
		end
	end
	//`DEBUG("Here3 a:%b b:%b zExp:%b (%b) zSigExt:%b sticky:%b",a,b,zExp,`EXP_NORMAL_MAX(EXP_W-1),zSigExt,sticky);

	if(zSigExt[SIG_W+3:SIG_W+2]!=2'b01 && zSigExt!=0) begin
		$display("zSigExt has wrong leading 1 bit!! %d-- a:%b b:%b largerSig:%b smallerSig:%b smallerSigSh:%b zSigExt:%b",
		         opType, a,b, largerSig, smallerSig, smallerSigSh, zSigExt);
		$finish();
	end
	zSig=zSigExt[SIG_W+1:2];
	GRT={zSigExt[1:0],sticky};
end

endmodule

module R5FP_mul #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
    input  [2:0] rnd,
    output reg [7:0] status,
	output [EXP_W+SIG_W:0] z);

wire sign, isNaN, newNaN, isINF, isZero, useA,useB;
R5FP_mul_special_cases #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) sp (
	.a(a), .b(b),
    .sign(sign), .isNaN(isNaN), .newNaN(newNaN), .isINF(isINF), .isZero(isZero), .useA(useA), .useB(useB));

wire [EXP_W+SIG_W*2+1:0] z_tmp;
reg [EXP_W+SIG_W*2+1:0] z_tmp2;
R5FP_mul_core #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) mul (
	.a(a), .b(b), .z(z_tmp));

reg [6:0] status_tmp;
always @(*) begin
	status_tmp=0;
	status_tmp[`IS_NAN]=isNaN;
	status_tmp[`IS_INF]=isINF;
	status_tmp[`IS_ZERO]=isZero;
	if(isNaN||isINF) status_tmp[`SIGN]=sign;
	z_tmp2=z_tmp;
	if(isNaN) begin
		z_tmp2[SIG_W*2:SIG_W+1]=newNaN? 1 : ({SIG_W{useA}}&a[SIG_W-1:0])|({SIG_W{useB}}&b[SIG_W-1:0]);
	end
	//`DEBUG("Here6 z_tmp2:%b isNaN:%b newNaN:%b",z_tmp2,isNaN,newNaN);
end

reg [EXP_W-1:0] tailZeroCnt;
wire [EXP_W-1:0] zExp_tmp=z_tmp[EXP_W+SIG_W*2:SIG_W*2+1];
always @(*) begin
	tailZeroCnt=0;
	if(zExp_tmp>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && zExp_tmp<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
		tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-zExp_tmp);
	end
	//`DEBUG("Here7 tailZeroCnt:%b zExp_tmp:%b %b %b",tailZeroCnt,zExp_tmp,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),`EXP_DENORMAL_MAX(EXP_W-1));
end
R5FP_postproc #(
        .I_SIG_W(SIG_W*2+1+2),
        //.I_EXP_W(EXP_W+1),  
        .SIG_W(SIG_W),
        .EXP_W(EXP_W)) pp (
        .aExp(zExp_tmp),
        .aStatus(status_tmp),
        .aSig({2'b01, z_tmp2[SIG_W*2:0]}),
		.tailZeroCnt(tailZeroCnt),
        .rnd(rnd),
		.aSign(z_tmp2[EXP_W+SIG_W*2+1]),
        .z(z),
        .status(status));

endmodule


module R5FP_mul_special_cases #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
    output reg sign, isNaN, newNaN, isINF, isZero, useA, useB);

localparam E_MAX=((1<<EXP_W)-1);
    
wire a_s, b_s;
wire [EXP_W-1:0] a_e, b_e;
wire [SIG_W-1:0] a_m, b_m;
assign {a_s,a_e,a_m}=a; 
assign {b_s,b_e,b_m}=b; 

always@(*)   begin
	sign=0;
	isNaN=0;
	isINF=0;
	isZero=({a_e,a_m}==0||{b_e,b_m}==0);
	sign=a_s^b_s;
	//if a is NaN or b is NaN return NaN 
	if ((a_e==E_MAX && a_m != 0)) begin
		isNaN = 1;
		useA=1;
	end
	if ((b_e==E_MAX && b_m != 0)) begin
		isNaN = 1;
		useB=1;
	end
	//if a is inf return inf
	else if (a_e == E_MAX) begin
		isINF=1;
	    //if b is zero return NaN
	    if ((b_e == 0) && (b_m == 0)) begin
		    isINF=0;
		    isNaN=1;
			newNaN=1;
			isZero=0;
	    end
	end 
	//if b is inf return inf
	else if (b_e == E_MAX) begin
		isINF=1;
	    //if a is zero return NaN
	    if ((a_e == 0) && (a_m == 0)) begin
		    isINF=0;
		    isNaN=1;
			newNaN=1;
			isZero=0;
	    end
	end 
end
endmodule

module R5FP_mul_core #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
	output [EXP_W+SIG_W*2+1:0] z);

reg zSign;
reg signed [EXP_W:0] zExp;
reg [SIG_W*2:0] zSig;
reg [SIG_W*2+1:0] zSigExt;
assign z={zSign,zExp[EXP_W-1:0],zSig};

wire aSign=a[EXP_W+SIG_W];
wire bSign=b[EXP_W+SIG_W];
wire [SIG_W:0] aSig={1'b1,a[SIG_W-1:0]};
wire [SIG_W:0] bSig={1'b1,b[SIG_W-1:0]};
wire [EXP_W-1:0] aExp=a[EXP_W+SIG_W-1:SIG_W];
wire [EXP_W-1:0] bExp=b[EXP_W+SIG_W-1:SIG_W];

always @(*) begin
	zSigExt=aSig*bSig;
	zSign=aSign^bSign;
	if(zSigExt[SIG_W*2+1]==1'b0) begin
		zExp=aExp+bExp+1;
		zSigExt=zSigExt<<1;
	end
	else begin
		zExp=aExp+bExp+2;
	end

	zExp=zExp-(1<<(EXP_W-1));
	if(zExp<`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-3) zExp=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-3;
	else if(zExp>`EXP_NORMAL_MAX(EXP_W-1)) zExp=`EXP_NORMAL_MAX(EXP_W-1)+1;

	if(zSigExt[SIG_W*2+1]!=1'b1) begin
		$display("zSigExt has wrong leading 1 bit!!");
	end
	zSig=zSigExt[SIG_W*2:0];
end

endmodule


module R5FP_postproc #(
        parameter I_SIG_W=25,
        parameter SIG_W=23,
        parameter EXP_W=9) (
        input [EXP_W-1:0] aExp,
        input [7-1:0] aStatus,
        input [I_SIG_W-1:0] aSig,
        input  [2:0] rnd,
		input aSign,
        input [EXP_W-1:0] tailZeroCnt,
        output reg [SIG_W+EXP_W:0] z,
        output reg [7:0] status);

`define FUNC_POSTPROC func_postproc
`include "R5FP_postproc.v"
`undef FUNC_POSTPROC

always @(*) begin
	 func_postproc(
        .aExp(aExp),
        .aStatus(aStatus),
        .aSig(aSig),
        .rnd(rnd),
		.aSign(aSign),
        .tailZeroCnt(tailZeroCnt),
        .z(z),
        .status(status));
end
endmodule

module R5FP_fp2fp_expand #(
	parameter SIG_W=10,
	parameter EXP_W=5,
	parameter SIG_W_INCR=1,
	parameter EXP_W_INCR=1) (
	input [SIG_W+EXP_W:0] a,
	output reg [SIG_W+SIG_W_INCR+EXP_W+EXP_W_INCR:0] z);

localparam SIG_W_O=SIG_W_INCR+SIG_W;
localparam EXP_W_O=EXP_W_INCR+EXP_W;
always @(*) begin
	z[SIG_W_O+EXP_W_O]=a[SIG_W+EXP_W];
	z[SIG_W_O-1:0]={a[SIG_W-1:0], {SIG_W_INCR{1'b0}}};
	if(a[SIG_W+EXP_W-1:SIG_W]=={EXP_W{1'b1}}) begin
		z[SIG_W_O+EXP_W_O-1:SIG_W_O] = {EXP_W_O{1'b1}};
	end
	else if(a[SIG_W+EXP_W-1:SIG_W]=={EXP_W{1'b0}}) begin
		z[SIG_W_O+EXP_W_O-1:SIG_W_O] = 0;
	end
	else begin
		z[SIG_W_O+EXP_W_O-1:SIG_W_O] = a[SIG_W+EXP_W-1:SIG_W] + ( (1<<EXP_W_O)/2 - (1<<EXP_W)/2 );
	end
end
endmodule 

module R5FP_exp_incr #(
	parameter SIG_W=10,
	parameter EXP_W=5) (
	input [SIG_W+EXP_W:0] a,
	output [SIG_W+EXP_W+1:0] z);

localparam a_width=SIG_W;
localparam addr_width=$clog2(a_width)+1;
`include "DW_lzd_function.inc"

localparam EXP_W_O=EXP_W+1;
wire [EXP_W-1:0] aExp=a[SIG_W+EXP_W-1:SIG_W];
wire [SIG_W-1:0] aSig=a[SIG_W-1:0];
reg [addr_width-1:0] lzCount;
reg [EXP_W_O-1:0] zExp;
reg [SIG_W-1:0] zSig;
assign z={a[SIG_W+EXP_W],zExp,zSig};

always @(*) begin
	zExp = aExp + ( (1<<EXP_W_O)/2 - (1<<EXP_W)/2 );
	zSig = aSig;
	lzCount=0;
	if(aExp==0) begin
		if(aSig==0) begin
			zExp=0;
			zSig=0;
		end
		else begin
			lzCount=DWF_lzd_enc(aSig);
			zExp=zExp-lzCount;
			zSig=zSig<<lzCount;
			zSig=zSig<<1;
		end
	end
	else if(aExp=={EXP_W{1'b1}}) begin
		zExp = {EXP_W_O{1'b1}};
	end
	//$display("Here4: a:%b aSig:%b zSig:%b lzCount:%b aSig<<lzCount:%b",a,aSig,zSig,lzCount,aSig<<lzCount);
end

endmodule

module R5FP_exp_decr #(
	parameter SIG_W=10,
	parameter EXP_W=5) (
	input [SIG_W+EXP_W+1:0] a,
	output [SIG_W+EXP_W:0] z);

localparam EXP_W_I=EXP_W+1;
localparam enc_width=$clog2(SIG_W)+1;
wire [EXP_W_I-1:0] aExp=a[SIG_W+EXP_W_I-1:SIG_W];
wire [SIG_W-1:0] aSig=a[SIG_W-1:0];
reg [enc_width-1:0] shCount;
reg [EXP_W-1:0] zExp;
reg [SIG_W-1:0] zSig;
assign z={a[SIG_W+EXP_W_I],zExp,zSig};

always @(*) begin
	zExp = aExp - ( (1<<EXP_W_I)/2 - (1<<EXP_W)/2 );
	zSig = aSig;
	if(aExp==0) begin
		zExp=0;
		zSig=0;
	end
	else if(aExp=={EXP_W_I{1'b1}}) begin
		zExp = {EXP_W{1'b1}};
	end
	else if(aExp>=`EXP_DENORMAL_MIN(EXP_W,SIG_W)&&aExp<=`EXP_DENORMAL_MAX(EXP_W)) begin
		shCount=1+(`EXP_DENORMAL_MAX(EXP_W)-aExp);
		zSig={1'b1,aSig}>>shCount;
		zExp=0;
	end
	//$display("Here4: zSig:%b shCount:%b aExp:%b zExp:%b %b %b",zSig,shCount,aExp,zExp,`EXP_DENORMAL_MIN(EXP_W,SIG_W),`EXP_DENORMAL_MAX(EXP_W));
end

endmodule

`undef DEBUG
