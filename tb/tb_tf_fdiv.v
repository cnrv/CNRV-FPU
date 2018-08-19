
`include "R5FP_inc.vh"

module R5FP_div_wrap #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	localparam ExtWidth=(SIG_W%2==1)? (SIG_W + 3) : (SIG_W + 4) ) (
		input  [SIG_W + EXP_W:0] a_i, b_i,
		input  [2:0] rnd_i,
		input strobe_i,
		output reg [SIG_W + EXP_W:0] z_o,
		output [SIG_W + EXP_W+1:0] zx,
		output reg [7:0] status_o,

		output done_o, ready_o,
		input clk,reset);

wire [EXP_W+SIG_W+1:0] ax,bx;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) a_exp_incr (.a(a_i), .z(ax));
R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) b_exp_incr (.a(b_i), .z(bx));

logic [ExtWidth-1:0] idiv_D,idiv_N;
logic idiv_strobe;
logic [ExtWidth-1:0] idiv_Quo, idiv_Rem;
logic idiv_done;
logic idiv_ready;
logic [EXP_W:0] xExp;
logic [SIG_W+3-1:0] xSig;
logic [4:0] xMidStatus;
logic [7:0] xStatus_fast;
logic [7:0] zStatus;
logic  [SIG_W+EXP_W+1:0] x_fast;
logic use_fast;
logic [2:0] rnd;
R5FP_div #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) div (
		.a_i(ax),
		.b_i(bx),
		.rnd_i(rnd_i),
		.strobe_i(strobe_i),
		.xExp_o(xExp),
		.xSig_o(xSig),
		.xMidStatus_o(xMidStatus),

		.xStatus_fast_o(xStatus_fast),
		.x_fast_o(x_fast),
		.x_use_fast(use_fast),
		.rnd_o(rnd),

		.idiv_N(idiv_N), 
		.idiv_D(idiv_D),
		.idiv_strobe(idiv_strobe),
		.idiv_Quo(idiv_Quo),
		.idiv_Rem(idiv_Rem),
		.idiv_done(idiv_done),
		.idiv_ready(idiv_ready),

		.done_o(done_o), 
		.ready_o(ready_o),
		.clk(clk),
		.reset(reset));

R5FP_int_div_sqrt #(.W(ExtWidth)) 
	int_div_sqrt (
		.N_i(idiv_N),
		.D_i(idiv_D),
		.strobe_i(idiv_strobe), 
		.is_div_i(1'b1),
		.Quo_o(idiv_Quo), 
		.Rem_o(idiv_Rem),
		.done_o(idiv_done),
		.ready_o(idiv_ready),
		.clk(clk),
		.reset(reset));

R5FP_postproc #(
		.I_SIG_W(SIG_W+4),
		.SIG_W(SIG_W),
		.EXP_W(EXP_W+1)) pp (
		.aExp(xExp),
		.aStatus(xMidStatus),
		.aSig({1'b0,xSig}),
		.rnd(rnd),
		.aSign(xMidStatus[`SIGN]),
		.z(zx),
		.zStatus(zStatus));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_decr (.a(use_fast? x_fast : zx), .z(z_o));

assign status_o=use_fast? xStatus_fast : zStatus;

endmodule


///////////////////////////////////////////////////////////////////

module tb_fdiv(input clk, reset, input [2:0] rnd);

parameter SIG_W=23;
parameter EXP_W=8;

logic done,strobe;
logic [7:0] status;
logic [SIG_W+EXP_W:0] a,b,z0;
logic [SIG_W-1:0] aSig,bSig,z0Sig,zSig,zxSig;
logic [EXP_W-1:0] aExp,bExp,z0Exp,zExp;
logic [EXP_W:0] zxExp;
logic aSign,bSign,zSign,z0Sign;
/* verilator lint_off UNUSED */
logic zxSign;
/* verilator lint_on UNUSED */
assign {aSign,aExp,aSig}=a;
assign {bSign,bExp,bSig}=b;
assign {z0Sign,z0Exp,z0Sig}=z0;

R5FP_div_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a_i({aSign,aExp,aSig}),
	.b_i({bSign,bExp,bSig}),
	.rnd_i(rnd),
	.strobe_i(strobe),
	.z_o({zSign,zExp,zSig}),
	.zx({zxSign,zxExp,zxSig}),
	.status_o(status),
	.done_o(done),
	/* verilator lint_off PINCONNECTEMPTY */
	.ready_o(),
	/* verilator lint_on PINCONNECTEMPTY */
	.clk(clk),
	.reset(reset));

logic [4:0] s0pre,s0,yS;
assign yS=to_tf_flags(status);

integer fd, readcount;
initial begin
	fd=$fopen("/dev/stdin","r");
	$display("fd is %d", fd);
end

/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if(done&&!reset) begin
		reg pass;
		s0=s0pre;
		s0[3]=0; //useless bit

		pass=(z0Sig==zSig && z0Exp==zExp && zSign==z0Sign);

		//special case for NaN
		if((&z0Exp)==1&&(&zExp)==1&&z0Sig!=0&&zSig!=0) pass=1;

		if(z0Exp!=0) s0[1]=1'b0; // fix an underflow bug of testfloat?
		if(s0!=yS) pass=0;
		if(pass) begin
			//$display("Pass");
		end
		else begin
			$display("Fail!! %d", $time);
			$display("input: a b: %08h %08h",a,b);
			$display("input: a:%b-%b-%b b:%b-%b-%b",aSign,aExp,aSig,bSign,bExp,bSig);
			$display("z0Sign:%b z0Sig:%b z0Exp:%b s0:%b",z0Sign,z0Sig,z0Exp,s0);
			$display("zSign:%b  zSig :%b zExp :%b yS:%b %b",zSign,zSig, zExp, yS, status);
			$display("zxSig:%b zxExp:%b",zxSig, zxExp);
			$display("use_fast_r :%b ", I.div.use_fast_r);
			$finish();
		end
	end
end

always @(negedge clk) begin
	logic [SIG_W+EXP_W:0] a_nxt,b_nxt,z0_nxt;
	logic [4:0] s0pre_nxt;
	if(reset) begin
		readcount = $fscanf(fd, "DUMP: %x %x %x %x", a_nxt, b_nxt, z0_nxt, s0pre_nxt);
		a<=a_nxt; b<=b_nxt; z0<=z0_nxt; s0pre<=s0pre_nxt;
		$display("New data:  %h %h %h %b", a_nxt, b_nxt, z0_nxt, s0pre_nxt);
		if(readcount != 4) $display("Read Error! %d", readcount);
	end
	else begin
		if(done) begin
			readcount = $fscanf(fd, "DUMP: %x %x %x %x", a_nxt, b_nxt, z0_nxt, s0pre_nxt);
			a<=a_nxt; b<=b_nxt; z0<=z0_nxt; s0pre<=s0pre_nxt;
			//$display("%d New data:  %h %h %h %b", $time, a_nxt, b_nxt, z0_nxt, s0pre_nxt);
			if(readcount != 4) begin
				$display("Read Error! %d", readcount);
				$finish();
			end
		end
	end
end
/* verilator lint_on BLKSEQ */

always @(posedge clk) begin
	if(reset) strobe<=1'b1;
	else if (strobe) strobe<=1'b0;
	else if (done) strobe<=1'b1;
end



endmodule

