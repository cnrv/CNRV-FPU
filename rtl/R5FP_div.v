
`include "R5FP_inc.vh"

module R5FP_div_special_cases #(
	parameter EXP_W=5,
	parameter SIG_W=10) (
	input [EXP_W+SIG_W:0] a, b,
	output reg sign, isNaN, newNaN, isINF, isInvalid, isZero, isDivByZero, isOne, useA, useB);

localparam E_MAX=((1<<EXP_W)-1);
    
wire a_s, b_s;
wire [EXP_W-1:0] a_e, b_e;
wire [SIG_W-1:0] a_m, b_m;
assign {a_s,a_e,a_m}=a; 
assign {b_s,b_e,b_m}=b; 

always@(*)   begin
	isNaN=0;
	isINF=0;
	useA=0;
	useB=0;
	isInvalid=0;
	isZero=0;
	isDivByZero=0;
	isOne=0;
	sign=a_s^b_s;
	newNaN=0;
	if ( a_e == E_MAX ) begin //A is Inf||NaN
		if ( a_m!=0 ) begin //A is NaN
			isNaN=1;
			useA=1;
		end
		else if ( b_e == E_MAX ) begin //A is Inf and B is Inf||NaN
			newNaN=1;
			if ( b_m==0 ) begin //B is Inf
				isInvalid=1;
			end
		end
		else begin //A is Inf and B is normal
			isINF=1;
		end
	end
	else if ( b_e == E_MAX ) begin //A is normal and B is Inf||NaN
		if ( b_m!=0 ) begin //B is NaN
			isNaN=1;
			useB=1;
		end
		else begin //B is Inf
			isZero=1;
		end
	end
	else if ( b_e == 0 ) begin //A is normal and B is zero
		if({a_e,a_m}==0) begin // A is zero
			newNaN=1;
			isInvalid=1;
		end
		else begin //A is not zero
			isDivByZero=1;
			isINF=1;
		end
	end
	else if ( a_e == 0 ) begin //A is zero and B is not zero
		isZero=1;
	end
	else begin //A is not zero and B is not zero
		isOne=(a_m==b_m);
	end
end
endmodule

module R5FP_div #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	localparam ExtWidth=(SIG_W%2==1)? (SIG_W + 3) : (SIG_W + 4) ) (
		input  [SIG_W + EXP_W:0] a_i, b_i,
		input  [2:0] rnd_i,
		input strobe_i,
		output [EXP_W-1:0] xExp_o,tailZeroCnt_o,
		output [SIG_W+3-1:0] xSig_o,
		output [5:0] xMidStatus_o,

		output [7:0] xStatus_fast_o,
		output  [SIG_W + EXP_W:0] x_fast_o,
		output x_use_fast,
		output [2:0] rnd_o,

		output [ExtWidth-1:0] idiv_N, 
		output [ExtWidth-1:0] idiv_D, 
		output idiv_strobe,
		input [ExtWidth-1:0] idiv_Quo, 
		input [ExtWidth-1:0] idiv_Rem,
		input idiv_done,
		input idiv_ready,

		output done_o, ready_o,
		input clk,reset);
	
reg  [2:0] rnd_r;
reg [EXP_W - 1:0] aExp_r;
reg [SIG_W - 1:0] aSig_r;
reg aSign_r;
reg [EXP_W - 1:0] bExp_r;
reg [SIG_W - 1:0] bSig_r;
reg bSign_r;
reg signed [EXP_W+1:0] xExp;
reg signed [EXP_W-1:0] xExp_r, tailZeroCnt_r;
reg [8     - 1:0] status_fast;
reg [(EXP_W + SIG_W):0] x_fast;
reg [8     - 1:0] status_reg;
reg [(EXP_W + SIG_W):0] x_reg;
reg strobe_r;
always @(posedge clk) begin
	if(reset) strobe_r<=1'b0;
	else if(strobe_i) strobe_r<=1'b1;
	else if(strobe_r) strobe_r<=1'b0;
end

always @(posedge clk) begin
	if(reset) begin
		rnd_r<=0;
	end
	else if(strobe_i) begin
		//$display("%d Get New input a:%b-%b b:%b-%b", $time,
		//	a_i[((EXP_W + SIG_W) - 1):SIG_W],a_i[(SIG_W - 1):0],
		//	b_i[((EXP_W + SIG_W) - 1):SIG_W],b_i[(SIG_W - 1):0]);
		aExp_r<=a_i[((EXP_W + SIG_W) - 1):SIG_W];
		aSig_r<=a_i[(SIG_W - 1):0];
		aSign_r<=a_i[(EXP_W + SIG_W)];
		bExp_r<=b_i[((EXP_W + SIG_W) - 1):SIG_W];
		bSig_r<=b_i[(SIG_W - 1):0];
		bSign_r<=b_i[(EXP_W + SIG_W)];
		rnd_r<=rnd_i;
	end
end
assign rnd_o=rnd_r;

wire sign, isNaN, newNaN, isINF, isInvalid, isZero, isDivByZero, isOne, useA, useB;
reg toInf;
wire use_fast=isZero|isINF|isNaN|newNaN|isOne|toInf;
reg use_fast_r;
assign idiv_strobe=strobe_r&~use_fast;
R5FP_div_special_cases #(.EXP_W(EXP_W), .SIG_W(SIG_W)) sp (
	.a({aSign_r,aExp_r,aSig_r}),
	.b({bSign_r,bExp_r,bSig_r}),
	.sign(sign), .isNaN(isNaN), .newNaN(newNaN), 
	.isINF(isINF), .isInvalid(isInvalid), .isZero(isZero), 
	.isDivByZero(isDivByZero), .isOne(isOne), .useA(useA), .useB(useB));

wire rightShiftA = aSig_r>bSig_r;
always @(*) begin
	toInf=0;
	xExp = {1'b0,aExp_r} - {1'b0,bExp_r} + { {EXP_W{1'b0}}, rightShiftA };
	if(isOne) begin
		xExp = xExp + ((1 << (EXP_W-1)) - 1);
	end
	else begin
		xExp = xExp + ((1 << (EXP_W-1)) - 1) - 1;
	end
	if(xExp<`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-3) begin
		xExp=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-3;
	end
	else if(xExp>`EXP_NORMAL_MAX(EXP_W-1)) begin
		xExp=`EXP_NORMAL_MAX(EXP_W-1)+1;
		if(aSig_r>=bSig_r) toInf=1;
	end
end

always @(*) begin
	logic [EXP_W-1:0] tmpExp;
	logic awayFromInf;
	status_fast = 0;
	status_fast[`Z_INVALID] = isInvalid;
	status_fast[`Z_IS_INF] = isINF;
	status_fast[`Z_IS_ZERO] = isZero;
	status_fast[`Z_DIV_BY_0] = isDivByZero;
	x_fast = {sign, {EXP_W{1'b1}}, 1'b1, {(SIG_W-1){1'b0}}}; //INF

	if(isZero) x_fast = {sign, {EXP_W{1'b0}}, {SIG_W{1'b0}}};
	else if(isINF) x_fast = {sign, {EXP_W{1'b1}}, {SIG_W{1'b0}}};
	else if(isNaN&&useA) x_fast = {sign, aExp_r, aSig_r};
	else if(isNaN&&useB) x_fast = {sign, bExp_r, bSig_r};
	else if(isOne) begin
		x_fast={sign, xExp[EXP_W-1:0], {SIG_W{1'b0}}};
		if(xExp<`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)) begin
			if( (rnd_r==`RND_UP&&sign==1'b0)||
			    (rnd_r==`RND_DOWN&&sign==1'b1)||
			(rnd_r==`RND_FROM_ZERO) ||
			(rnd_r==`RND_NEAREST_UP&&xExp==`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-1)) begin
				tmpExp=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W);
				x_fast={sign, tmpExp, {SIG_W{1'b0}}};
				status_fast[`Z_IS_ZERO] = 0;
`ifdef FORCE_DW_DIV_BEHAVIOR
				status_fast[`Z_TINY] = 0;
`else
				status_fast[`Z_TINY] = 1;
`endif
				status_fast[`Z_INEXACT] = 1;
			end
			else begin
				x_fast={sign, {EXP_W{1'b0}}, {SIG_W{1'b0}}};
				status_fast[`Z_IS_ZERO] = 1;
				status_fast[`Z_TINY] = 1;
				status_fast[`Z_INEXACT] = 1;
			end
		end
	end

	if(toInf&&(!isINF)&&(!isNaN)) begin
		x_fast={sign, {EXP_W{1'b1}}, {SIG_W{1'b0}}};
		status_fast[`Z_IS_INF] = 1;
		status_fast[`Z_HUGE] = 1;
		status_fast[`Z_INEXACT] = 1;
	end

	awayFromInf=(rnd_r==`RND_TO_ZERO ||
		(rnd_r==`RND_UP && sign==1'b1) ||
		(rnd_r==`RND_DOWN && sign==1'b0) );
	if(awayFromInf&&(!isINF)&&(!isNaN)&&xExp==`EXP_NORMAL_MAX(EXP_W-1)+1) begin
		// larger than the largest possible value by 1
		tmpExp=`EXP_NORMAL_MAX(EXP_W-1);
		x_fast={sign, tmpExp, {SIG_W{1'b1}}};
		status_fast[`Z_IS_INF] = 0;
		status_fast[`Z_HUGE] = 1;
		status_fast[`Z_INEXACT] = 1;
	end
end

//always @(posedge clk) begin
//	$display("%d X aExp_r:%b bExp_r:%b rightShiftA:%b xExp:%b(max:%b min:%b) status_fast:%b isOne:%b use_fast:%b toInf:%b isINF:%b newNaN:%b",$time,aExp_r,bExp_r,rightShiftA,xExp,`EXP_NORMAL_MAX(EXP_W),`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),status_fast, isOne, use_fast, toInf, isINF, newNaN);
//end
	
generate
	// idiv_D's length must be even 
	if (SIG_W%2==1) begin
		assign idiv_N = rightShiftA? {3'b001, aSig_r} : {2'b01, aSig_r, 1'b0};
		assign idiv_D = {2'b01, bSig_r, 1'b0};
	end
	else begin
		assign idiv_N = rightShiftA? {3'b001, aSig_r, 1'b0} : {2'b01, aSig_r, 2'b0};
		assign idiv_D = {2'b01, bSig_r, 2'b0};
	end
endgenerate

always @(posedge clk) begin
	//if(idiv_strobe) $display("%d idiv_D:%b aSig_r:%b expNoBias:%b aExp_r:%b",$time, 
	//	idiv_D, aSig_r, expNoBias, aExp_r);
	//$display("%d use_fast:%b  a:%b-%b strobe_r:%b x_fast:%b status_fast:%b",
	//	$time, use_fast,  aExp_r, aSig_r, strobe_r, x_fast, status_fast);
	reg [EXP_W-1:0] exp;
	exp=xExp[EXP_W-1:0];
	if(strobe_r) begin
		if(use_fast) begin
			x_reg<=x_fast;
			status_reg<=status_fast;
		end
		else begin
			xExp_r<=exp;
			if(exp>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && exp<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
				tailZeroCnt_r<=1+(`EXP_DENORMAL_MAX(EXP_W-1)-exp);
			end
			else begin
				tailZeroCnt_r<=0;
			end
		end
	end
end
assign xExp_o=xExp_r;
assign tailZeroCnt_o=tailZeroCnt_r;

always @(posedge clk) begin
	if(reset) use_fast_r<=1'b0;
	else if(strobe_r) use_fast_r<=use_fast;
	else if(use_fast_r) use_fast_r<=1'b0;
end


wire [ExtWidth-1:0] Quo={ExtWidth{idiv_done}}&idiv_Quo;

wire stickyBit;
wire roundBit;
wire [SIG_W+2-1:0] xSig;
generate
	if (SIG_W%2==1) begin
		assign stickyBit = idiv_Rem!=0;
		assign xSig = Quo[ExtWidth - 1:1];
		assign roundBit = Quo[0];
	end
	else begin
		assign stickyBit = idiv_Rem!=0 || Quo[0]!=0;
		assign xSig = Quo[ExtWidth - 1:2];
		assign roundBit = Quo[1];
	end
endgenerate

assign xSig_o={xSig,roundBit};
assign xMidStatus_o={1'b0, sign, stickyBit, 3'b0};

assign xStatus_fast_o = status_reg;
assign x_fast_o = x_reg;
assign x_use_fast = use_fast_r;

assign done_o = use_fast_r||idiv_done;
assign ready_o = idiv_ready&&~strobe_r;

endmodule
