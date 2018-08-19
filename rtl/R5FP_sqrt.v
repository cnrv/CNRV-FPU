
`include "R5FP_inc.vh"

module R5FP_sqrt #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	localparam ExtWidth=(SIG_W%2==1)? (SIG_W + 3) : (SIG_W + 4) ) (
		input  [SIG_W + EXP_W:0] a_i,
		input  [2:0] rnd_i,
		input strobe_i,
		output reg [SIG_W + EXP_W:0] z_o,
		output reg [7:0] status_o,

		output [ExtWidth-1:0] isqrt_D, 
		output isqrt_strobe,
		input [ExtWidth-1:0] isqrt_Quo, 
/* verilator lint_off UNUSED */
		input [ExtWidth-1:0] isqrt_Rem,
/* verilator lint_on UNUSED */
		input isqrt_done,
		input isqrt_ready,

		output done_o, ready_o,
		input clk,reset);
	
reg  [2:0] rnd_r;
reg [EXP_W - 1:0] aExp_r;
reg [SIG_W - 1:0] aSig_r;
reg aSign_r;
reg signed [EXP_W+2:0] zExp;
reg signed [EXP_W-1:0] zExp_r;
reg signed [EXP_W-1:0] zExp_tmp;
reg [8     - 1:0] status_fast;
reg [8     - 1:0] status_normal;
reg [8     - 1:0] status_reg;
reg [(EXP_W + SIG_W):0] z_fast;
reg [(EXP_W + SIG_W):0] z_reg;
reg [(EXP_W + SIG_W):0] z_normal;
reg use_fast, use_fast_r;
reg strobe_r;
always @(posedge clk) begin
	if(reset) strobe_r<=1'b0;
	else if(strobe_i) strobe_r<=1'b1;
	else if(strobe_r) strobe_r<=1'b0;
end
assign isqrt_strobe=strobe_r&~use_fast;

always @(posedge clk) begin
	if(reset) begin
		rnd_r<=0;
	end
	else if(strobe_i) begin
		//$display("Get new input:%b-%b",a_i[((EXP_W + SIG_W) - 1):SIG_W],a_i[(SIG_W - 1):0]);
		aExp_r<=a_i[((EXP_W + SIG_W) - 1):SIG_W];
		aSig_r<=a_i[(SIG_W - 1):0];
		aSign_r<=a_i[(EXP_W + SIG_W)];
		rnd_r<=rnd_i;
	end
end


always @(*) begin
	reg [(EXP_W + SIG_W):0] NaN_Reg;
	reg aExpIsAllOnes;
	reg aIsZero;
/* verilator lint_off UNUSED */
	reg [(EXP_W + SIG_W):0] INF_Reg;
	reg aIsNaN;
/* verilator lint_on UNUSED */
	reg negInput;
	
	status_fast = 0;
	z_fast=0;
	use_fast=1;
	aExpIsAllOnes = (aExp_r == ((((1 << (EXP_W-1)) - 1) * 2) + 1));
	
	aIsZero = (aExp_r == 0) && (aSig_r == 0);
	aIsNaN = ((&aExp_r) == 1) && (aSig_r != 0);
	NaN_Reg = {aSign_r, {(EXP_W){1'b1}}, 1'b1, {(SIG_W-1){1'b0}}}; 
	INF_Reg = {aSign_r, {(EXP_W){1'b1}}, 1'b0, {(SIG_W-1){1'b0}}}; 
	
	negInput = aSign_r & ~aIsZero;
	if (aExpIsAllOnes || negInput) begin
		//square root of Infinity, NaN and negative number
`ifdef FORCE_DW_SQRT_BEHAVIOR
		status_fast[`Z_INVALID] = aExpIsAllOnes || negInput;
		z_fast = NaN_Reg;
`else
		status_fast[`Z_INVALID] = negInput && !aIsNaN;
		z_fast = (aIsNaN||negInput)? NaN_Reg : INF_Reg;
`endif
	end
	else if (aIsZero) begin
		status_fast[`Z_IS_ZERO] = 1;
		z_fast = {a_i[(EXP_W + SIG_W)], {(SIG_W + EXP_W){1'b0}}};
	end
	else begin
		use_fast=0;
	end
end

reg signed [EXP_W+1:0] expNoBias;
always @(*) begin
/* verilator lint_off WIDTH */
	expNoBias = aExp_r - ((1 << (EXP_W-1)) - 1);
	zExp = $signed(expNoBias[EXP_W + 1:1]+expNoBias[0]);
	zExp = zExp + ((1 << (EXP_W-1)) - 1);
/* verilator lint_on WIDTH */
	assert(zExp>0);
end
	
generate
	// isqrt_D's length must be even 
	if (SIG_W%2==1) begin
		assign isqrt_D = expNoBias[0]? {3'b001, aSig_r} : {2'b01, aSig_r, 1'b0};
	end
	else begin
		assign isqrt_D = expNoBias[0]? {3'b001, aSig_r, 1'b0} : {2'b01, aSig_r, 2'b0};
	end
endgenerate

always @(posedge clk) begin
	//if(isqrt_strobe) $display("%d isqrt_D:%b aSig_r:%b expNoBias:%b aExp_r:%b",$time, 
	//	isqrt_D, aSig_r, expNoBias, aExp_r);
	//$display("%d use_fast:%b  a:%b-%b strobe_r:%b z_fast:%b status_fast:%b",
	//	$time, use_fast,  aExp_r, aSig_r, strobe_r, z_fast, status_fast);
	if(strobe_r) begin
		if(use_fast) begin
			z_reg<=z_fast;
			status_reg<=status_fast;
		end
		else begin
			zExp_r<=zExp[EXP_W-1:0];
		end
	end
end
always @(posedge clk) begin
	if(reset) use_fast_r<=1'b0;
	else if(strobe_r) use_fast_r<=use_fast;
	else if(use_fast_r) use_fast_r<=1'b0;
end


logic [ExtWidth-1:0] Quo;
logic expNeedInc,extraBit;
always @(*) begin
	Quo={ExtWidth{isqrt_done}}&isqrt_Quo ;
	expNeedInc=Quo[ExtWidth-1];
	extraBit=1'b0;
	if(expNeedInc) begin
		extraBit=Quo[0];
		Quo=(Quo>>1);
	end
end

wire stickyBit;
wire roundBit;
wire guardBit;
wire [SIG_W+2-1:0] zSig;
generate
	if (SIG_W%2==1) begin
		assign stickyBit = isqrt_Rem[0]||extraBit;
		assign zSig = Quo[ExtWidth - 1:1];
		assign roundBit = Quo[0];
		assign guardBit = Quo[1];
	end
	else begin
		assign stickyBit = isqrt_Rem[0] || extraBit || Quo[0]!=0;
		assign zSig = Quo[ExtWidth - 1:2];
		assign roundBit = Quo[1];
		assign guardBit = Quo[2];
	end
endgenerate

always @(*) begin
	reg [SIG_W+2-1:0] zSigX0,zSigX;
	reg sigIncr;
	
	sigIncr = getRoundCarry(rnd_r, 1'b0, guardBit, roundBit, stickyBit);
	
	// add round bit
	if (sigIncr) zSigX0 = zSig + 1;
	else zSigX0 = zSig;
	
	if (zSigX0[SIG_W+2-1:SIG_W+1-1] == 2'b0) begin
		zExp_tmp = zExp_r + {{(EXP_W-1){1'b0}},expNeedInc} - 2;
		zSigX = zSigX0 << 1;
	end
	else if (zSigX0[SIG_W+2-1] == 1'b0) begin
		zExp_tmp = zExp_r + {{(EXP_W-1){1'b0}},expNeedInc} - 1;
		zSigX = zSigX0;
	end
	else begin
		zExp_tmp=zExp_r + {{(EXP_W-1){1'b0}},expNeedInc} + 0;
		zSigX=zSigX0 >> 1;
	end
	
	status_normal = 0;
	status_normal[`Z_INEXACT] = roundBit|stickyBit;
	
	if(isqrt_done&&!reset) assert(zSigX[SIG_W+2-1:SIG_W+2-2]==2'b01);
	z_normal = {1'b0, zExp_tmp[EXP_W - 1:0], zSigX[SIG_W-1:0]};
	//$display("%d isqrt_Quo:%b Quo:%b Rem:%b g r t: %b %b %b \nzSig:%b zSigX0:%b zSigX:%b zExp_r:%b zExp_tmp:%b expNeedInc:%b",$time, 
	//	isqrt_Quo, Quo, isqrt_Rem, guardBit, roundBit, stickyBit, zSig, zSigX0, zSigX, zExp_r, zExp_tmp, expNeedInc);
end

assign status_o = use_fast_r ? status_reg : status_normal;
assign z_o = use_fast_r ? z_reg : z_normal;

assign done_o = use_fast_r||isqrt_done;
assign ready_o = isqrt_ready&&~strobe_r;

endmodule
