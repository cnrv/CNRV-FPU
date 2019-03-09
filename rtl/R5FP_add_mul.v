
`include "R5FP_inc.vh"

`define DEBUG $display

module R5FP_add #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,

	output [EXP_W-1:0] zExp,
	output reg [EXP_W-1:0] tailZeroCnt,
	output [6-1:0] zStatus,
	output [SIG_W+4-1:0] zSig,
	output zSign);

wire [EXP_W-1:0] a_e;
wire [SIG_W-1:0] a_m;
wire a_s;
assign {a_s,a_e,a_m}=a; 

R5FP_add_inner #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a(a), .b(b),
	.a_is_weak_Inf(1'b0),
	.rnd(3'b0),
	.a_s(a_s), .a_m_all_zero(a_m==0), .a_e_all_zero(a_e==0),
	.a_e_all_one(1==&a_e), .a_quiet_NaN(a_m[SIG_W-1]),
	.zExp(zExp),
	.zStatus(zStatus),
	.zSig(zSig),
	.zSign(zSign));

always @(*) begin
	tailZeroCnt=0;
	if(zExp>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && zExp<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
		tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-zExp);
	end
end
endmodule

module R5FP_add_inner #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
	input a_s, a_m_all_zero, a_e_all_zero, a_e_all_one, a_quiet_NaN,
	input a_is_weak_Inf,
	input [2:0] rnd,

	output [EXP_W-1:0] zExp,
	output reg [6-1:0] zStatus,
	output [SIG_W+4-1:0] zSig,
	output zSign);

wire sign, isNaN, isINF, useA, useB, isZero0, signalNaN, isInvalid;
R5FP_add_special_cases #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) sp (
	.a_s(a_s), .a_m_all_zero(a_m_all_zero), .a_e_all_zero(a_e_all_zero), 
	.a_is_weak_Inf(a_is_weak_Inf),
	.rnd(rnd),
	.a_e_all_one(a_e_all_one), .a_quiet_NaN(a_quiet_NaN), .b(b),
	.sign(sign), .isNaN(isNaN), .signalNaN(signalNaN), 
	.isInvalid(isInvalid),
	.isINF(isINF), .useA(useA), .useB(useB), .isZero(isZero0));

wire [2:0] GRT;
wire [EXP_W+SIG_W:0] z_tmp;
reg [EXP_W+SIG_W:0] z_tmp2;
wire isZero;
R5FP_add_core #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) add (
	.a(a), .b(b), .GRT(GRT), .isZero(isZero), .z(z_tmp));

always @(*) begin
	zStatus=0;
	zStatus[`INVALID]=isInvalid;
	zStatus[`IS_NAN]=isNaN;
	zStatus[`IS_INF]=isINF;
	zStatus[`IS_ZERO]=isZero0;
	if(isNaN||isINF) zStatus[`SIGN]=sign;
	if(useA==0&&useB==0) begin
		zStatus[`STICKY]=GRT[0];
		zStatus[`IS_ZERO]=isZero;
	end
	if(isNaN) begin
		z_tmp2[SIG_W-1:0]=0;
		if(signalNaN) z_tmp2[SIG_W-1:0]={1'b1, {(SIG_W-1){1'b0}} };
	end
	else begin
		if(useA) z_tmp2=a;
		else if(useB) z_tmp2=b;
		else z_tmp2=z_tmp;
	end
end

assign zExp=z_tmp2[EXP_W-1+SIG_W:SIG_W];
assign zSign=z_tmp2[EXP_W+SIG_W];
assign zSig={2'b01, z_tmp2[SIG_W-1:0], (useA==0&&useB==0)? GRT[2:1] : 2'b00};

endmodule

module R5FP_add_special_cases #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input a_s, a_m_all_zero, a_e_all_zero, a_e_all_one, a_quiet_NaN,
	input a_is_weak_Inf,
	input [2:0] rnd,
	input [EXP_W+SIG_W:0] b,
	output  reg sign, isNaN, signalNaN, isINF, useA, useB, isZero, isInvalid);

localparam E_MAX=((1<<EXP_W)-1);
    
wire b_s;
wire [EXP_W-1:0] b_e;
wire [SIG_W-1:0] b_m;
assign {b_s,b_e,b_m}=b; 

always@(*)   begin
	sign=0;
	isNaN=0;
	isINF=0;
	isInvalid=0;
	useB=(a_e_all_zero && a_m_all_zero);
	useA=(b_e==0 && b_m==0);
	signalNaN=0;
	isZero=useA&&useB;
	if (a_e_all_one && b_e==E_MAX && a_s!=b_s && a_m_all_zero && b_m==0) begin
		//if a and b are +inf and -inf and a is weak, pick b
		if(a_is_weak_Inf) begin
			isINF = 1;
			sign=b_s;
		end
		//if a and b are +inf and -inf, return NaN
		else begin
			isNaN = 1;
			signalNaN = 1;
			isInvalid = 1;
		end
	end 
	//if a is NaN return NaN 
	else if ((a_e_all_one && !a_m_all_zero)) begin
		isNaN = 1;
		signalNaN=!a_quiet_NaN;
	end
	//if b is NaN return NaN 
	else if ((b_e==E_MAX && b_m != 0)) begin
		isNaN = 1;
		signalNaN=!b_m[SIG_W-1];
	end 
	//if b is inf return inf
	else if (b_e==E_MAX) begin
		isINF = 1;
		sign=b_s;
	end
	//if a is inf return inf
	else if (a_e_all_one) begin
		logic ignore_weak;
		ignore_weak=(rnd==`RND_TO_ZERO || (rnd==`RND_DOWN && !a_s) || (rnd==`RND_UP && a_s) ) &&
			     a_is_weak_Inf;
		if(!ignore_weak) begin
			isINF = 1;
			sign=a_s;
		end 
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

localparam width = SIG_W+1;
localparam addr_width = $clog2(width);
/* verilator lint_off UNUSED */
/* verilator lint_off WIDTH */
`include "DW_lza_function.inc"
/* verilator lint_on UNUSED */
/* verilator lint_on WIDTH */

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
reg signed [EXP_W:0] shiftCnt;
reg signed [EXP_W-1:0] lzCount;
reg extraShift, sameSign;
reg [1:0] opType;
reg [SIG_W+3:0] largerSig, smallerSig, smallerSigSh;
/* verilator lint_off UNUSED */
reg [SIG_W+3:0] smallerSigSh1;
/* verilator lint_on UNUSED */
reg [SIG_W+3:0] zSigExt;
localparam [1:0] NORMAL_ADD=0;
localparam [1:0] NORMAL_SUB=1;
localparam [1:0] SPECIAL_SUB=2;

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
		lzCount=0;
		lzCount[addr_width-1:0]=DWF_lza(largerSig[SIG_W+2:2], smallerSigSh1[SIG_W+2:2]);
		if(expDiff==1||expDiff==-1||expDiff==0) opType=SPECIAL_SUB;
	end

	{smallerSigSh,sticky}=shiftRightJam(smallerSig, shiftCnt, extraShift);
	//`DEBUG("Here3.1 a:%b b:%b smallerSig:%b (%b) smallerSigSh:%b sticky:%b",a,b,smallerSig,shiftCnt,smallerSigSh,sticky);
	if(sameSign) zSigExt=largerSig + smallerSigSh;
	else         zSigExt=largerSig - smallerSigSh - { {(SIG_W+3){1'b0}}, sticky};

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

//synopsys translate_off
	if(zSigExt[SIG_W+3:SIG_W+2]!=2'b01 && zSigExt!=0) begin
		$display("zSigExt has wrong leading 1 bit!! %d-- a:%b b:%b largerSig:%b smallerSig:%b smallerSigSh:%b zSigExt:%b",
		         opType, a,b, largerSig, smallerSig, smallerSigSh, zSigExt);
		$finish();
	end
//synopsys translate_on
	zSig=zSigExt[SIG_W+1:2];
	GRT={zSigExt[1:0],sticky};
end

endmodule

module R5FP_mul #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,

	output [EXP_W-1:0] zExp,tailZeroCnt,
	output reg [6-1:0] zStatus,
	output [SIG_W*2+2:0] zSig,
	output toInf,
	output zSign);

wire sign, isNaN, signalNaN, isINF, isZero, isInvalid;
R5FP_mul_special_cases #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) sp (
	.a(a), .b(b),
	.sign(sign), .isNaN(isNaN), .signalNaN(signalNaN), 
	.isInvalid(isInvalid),
	.isINF(isINF), .isZero(isZero));

wire [EXP_W+SIG_W*2+1:0] z_tmp;
reg [SIG_W*2:0] tmpSig;
wire toInfPre;
R5FP_mul_core #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) mul (
	.a(a), .b(b), .z(z_tmp), 
	.toInf(toInfPre), .tailZeroCnt(tailZeroCnt));
assign toInf=toInfPre&&(!isINF)&&(!isNaN);

always @(*) begin
	zStatus=0;
	zStatus[`INVALID]=isInvalid;
	zStatus[`IS_NAN]=isNaN;
	zStatus[`IS_INF]=isINF;
	zStatus[`IS_ZERO]=isZero;
	if(isNaN||isINF) zStatus[`SIGN]=sign;
	tmpSig=z_tmp[SIG_W*2:0];
	if(isNaN) begin
		tmpSig[SIG_W*2:0]=0;
		if(signalNaN) tmpSig[SIG_W*2:0]={1'b1, {(SIG_W*2){1'b0}} };
	end
	//`DEBUG("Here6 tmpSig:%b isNaN:%b signalNaN:%b",tmpSig,isNaN,signalNaN);
end

assign zExp=z_tmp[EXP_W+SIG_W*2:SIG_W*2+1];
assign zSign=z_tmp[EXP_W+SIG_W*2+1];
assign zSig={2'b01, tmpSig[SIG_W*2:0]};

endmodule


module R5FP_mul_special_cases #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
	output reg sign, isNaN, signalNaN, isINF, isZero, isInvalid);

localparam E_MAX=((1<<EXP_W)-1);
    
wire a_s, b_s;
wire [EXP_W-1:0] a_e, b_e;
wire [SIG_W-1:0] a_m, b_m;
assign {a_s,a_e,a_m}=a; 
assign {b_s,b_e,b_m}=b; 

always@(*)   begin
	sign=0;
	isNaN=0;
	isInvalid=0;
	isINF=0;
	isZero=({a_e,a_m}==0||{b_e,b_m}==0);
	sign=a_s^b_s;
	//if inf*0 return NaN
	if ((a_e==E_MAX&&a_m==0&&b_e==0&&b_m==0)||
	    (b_e==E_MAX&&b_m==0&&a_e==0&&a_m==0)) begin
		isNaN = 1;
		signalNaN=1;
		isInvalid=1;
	end
	//if a is NaN or b is NaN return NaN 
	else if ((a_e==E_MAX && a_m != 0)) begin
		isNaN = 1;
		signalNaN=!a_m[SIG_W-1];
	end
	else if ((b_e==E_MAX && b_m != 0)) begin
		isNaN = 1;
		signalNaN=!b_m[SIG_W-1];
	end
	//if a is inf return inf
	else if (a_e == E_MAX) begin
		isINF=1;
		//if b is zero return NaN
		if ((b_e == 0) && (b_m == 0)) begin
			isINF=0;
			isNaN=1;
			signalNaN=1;
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
			signalNaN=1;
			isZero=0;
		end
	end 
end
endmodule

module R5FP_mul_by_1 #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a,
	output [EXP_W-1:0] zExp,
	output reg [6-1:0] zStatus,
	output [SIG_W*2+2:0] zSig,
	output zSign);

wire [EXP_W-1:0] bExp=(1<<EXP_W)/2-1;
wire [SIG_W-1:0] bSig=0;
wire [EXP_W+SIG_W:0] b={1'b0,bExp,bSig};
R5FP_mul #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) mul (
	.a(a), .b(b),
	.zExp(zExp),
/* verilator lint_off  PINCONNECTEMPTY */
	.tailZeroCnt(),
	.toInf(),
/* verilator lint_on PINCONNECTEMPTY */
	.zStatus(zStatus),
	.zSig(zSig),
	.zSign(zSign));

endmodule

module R5FP_mul_core #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
	output reg [EXP_W-1:0] tailZeroCnt,
	output [EXP_W+SIG_W*2+1:0] z,
	output reg toInf);

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
	toInf=0;
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
	if(zExp<`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-3) begin
		zExp=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-3;
	end
	else if(zExp>`EXP_NORMAL_MAX(EXP_W-1)+2) begin
		zExp=`EXP_NORMAL_MAX(EXP_W-1)+3;
		toInf=1;
	end

//synopsys translate_off
	if(zSigExt[SIG_W*2+1]!=1'b1) begin
		$display("zSigExt has wrong leading 1 bit!!");
	end
//synopsys translate_on
	tailZeroCnt=0;
	if(zExp[EXP_W-1:0]>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && zExp[EXP_W-1:0]<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
		tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-zExp[EXP_W-1:0]);
	end
	zSig=zSigExt[SIG_W*2:0];
end

endmodule

module R5FP_acc #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W-1:0] dExp,
	/* verilator lint_off UNUSED */
	input [6-1:0] dStatus,
	/* verilator lint_on UNUSED */
	input [SIG_W*2+2:0] dSig,
	input dSign,
	input toInf,
	input [EXP_W+SIG_W:0] c,
	input [2:0] rnd,

	output zToInf,
	output reg specialTiny,
	output [EXP_W-1:0] zExp,
	output reg [EXP_W-1:0] tailZeroCnt,
	output reg [6-1:0] zStatus,
	output [SIG_W*2+4:0] zSig,
	output zSign);

reg d_m_all_zero, d_e_all_zero, d_e_all_one;
always @(*) begin
	d_m_all_zero=0; d_e_all_zero=0; d_e_all_one=0;
	if(dStatus[`IS_NAN]) begin
		d_m_all_zero=0; d_e_all_zero=0; d_e_all_one=1;
	end
	else if(dStatus[`IS_INF]||toInf) begin
		d_m_all_zero=1; d_e_all_zero=0; d_e_all_one=1;
	end
	else if(dStatus[`IS_ZERO]) begin
		d_m_all_zero=1; d_e_all_zero=1; d_e_all_one=0;
	end
end

wire signalNaN=dSig[SIG_W*2];
wire d_quiet_NaN=!signalNaN;
wire [6-1:0] zStatusPre;
R5FP_add_inner #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W*2+1)) add (
	.a({dSign,dExp,dSig[SIG_W*2:0]}), 
	.b({c,{(SIG_W+1){1'b0}}}),
	.a_s(dSign), .a_m_all_zero(d_m_all_zero), .a_e_all_zero(d_e_all_zero), 
	.a_e_all_one(d_e_all_one), .a_quiet_NaN(d_quiet_NaN),
	.a_is_weak_Inf(toInf),
	.rnd(rnd),

	.zExp(zExp),
	.zStatus(zStatusPre),
	.zSig(zSig),
	.zSign(zSign));

always @(*) begin
	tailZeroCnt=0;
	if(zExp>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && zExp<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
		tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-zExp);
	end
end

assign zStatus={zStatusPre[`INVALID]|dStatus[`INVALID], zStatusPre[4:0]};

logic cSign;
logic [SIG_W-1:0] cSig;
logic [EXP_W-1:0] cExp;
assign {cSign,cExp,cSig}=c;
wire cIsInfOrNaN=(&cExp)==1;
assign zToInf=toInf&&!cIsInfOrNaN;

always @(*) begin
	reg dSmall,cSmall,diffSign,sameSignCross,cMarginal;
	specialTiny=0;
	if(rnd==`RND_NEAREST_EVEN||rnd==`RND_NEAREST_UP) begin
		dSmall=(dExp==`EXP_DENORMAL_MAX(EXP_W-1) || dExp==`EXP_DENORMAL_MAX(EXP_W-1)-1);
		cMarginal=(cExp==`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)&&cSig==0);
		diffSign=(!dStatus[`Z_IS_ZERO])&&(dSign!=cSign);
		cSmall=(cExp==`EXP_DENORMAL_MAX(EXP_W-1) || cExp==`EXP_DENORMAL_MAX(EXP_W-1)-1);
		sameSignCross=(!dStatus[`Z_IS_ZERO])&&cSmall&&(dSign==cSign);
		if(dSmall||(diffSign||sameSignCross)) 
			specialTiny=1;
		if(cMarginal)
			specialTiny=1;
	end
end

endmodule



`undef DEBUG
