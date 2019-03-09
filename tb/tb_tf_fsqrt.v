
`include "R5FP_inc.vh"


module R5FP_sqrt_wrap #(
	parameter SIG_W = 23,
	parameter EXP_W = 8,
	localparam ExtWidth=(SIG_W%2==1)? (SIG_W + 3) : (SIG_W + 4) ) (
		input  [SIG_W + EXP_W:0] a_i,
		input  [2:0] rnd_i,
		input strobe_i,
		output reg [SIG_W + EXP_W:0] z_o,
		output [SIG_W + EXP_W+1:0] zx,
		output reg [7:0] status_o,

		output done_o, ready_o,
		input clk,reset);

wire [EXP_W+SIG_W+1:0] ax;

R5FP_exp_incr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_incr (.a(a_i), .z(ax));

logic [ExtWidth-1:0] isqrt_D;
logic isqrt_strobe;
logic [ExtWidth-1:0] isqrt_Quo, isqrt_Rem;
logic isqrt_done;
logic isqrt_ready;
R5FP_sqrt #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W+1)) sqrt (
		.a_i(ax),
		.rnd_i(rnd_i),
		.strobe_i(strobe_i),
		.z_o(zx),
		.status_o(status_o),

		.isqrt_D(isqrt_D), 
		.isqrt_strobe(isqrt_strobe),
		.isqrt_Quo(isqrt_Quo),
		.isqrt_Rem(isqrt_Rem),
		.isqrt_done(isqrt_done),
		.isqrt_ready(isqrt_ready),

		.done_o(done_o), 
		.ready_o(ready_o),
		.clk(clk),
		.reset(reset));

R5FP_int_div_sqrt #(.W(ExtWidth)) 
	int_div_sqrt (
		.N_i({ExtWidth{1'b0}}),
		.D_i(isqrt_D),
		.strobe_i(isqrt_strobe), 
		.is_div_i(1'b0),
		.Quo_o(isqrt_Quo), 
		.Rem_o(isqrt_Rem),
		.done_o(isqrt_done),
		.ready_o(isqrt_ready),
		.clk(clk),
		.reset(reset));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_decr (.a(zx), .z(z_o));

endmodule

///////////////////////////////////////////////////////////////////

module tb_fsqrt(input clk, reset, input [2:0] rnd);

`ifdef FP64
parameter EXP_W=11;
parameter SIG_W=52;
`else
parameter SIG_W=23;
parameter EXP_W=8;
`endif

logic done,strobe;
logic [7:0] status;
logic [SIG_W+EXP_W:0] a,z0;
logic [SIG_W-1:0] aSig,z0Sig,zSig,zxSig;
logic [EXP_W-1:0] aExp,z0Exp,zExp;
logic [EXP_W:0] zxExp;
logic aSign,zSign,z0Sign;
/* verilator lint_off UNUSED */
logic zxSign;
/* verilator lint_on UNUSED */
assign {aSign,aExp,aSig}=a;
assign {z0Sign,z0Exp,z0Sig}=z0;

R5FP_sqrt_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a_i({aSign,aExp,aSig}),
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

		if(s0!=yS) pass=0;
		if(pass) begin
			//$display("Pass");
			//$display("zSig0:%b zExp0:%b s0:%b",zSig0,zExp0,s0);
			//$display("zSig :%b zExp :%b yS :%b",zSig, zExp, yS);
		end
		else begin
			$display("Fail!! %d", $time);
			$display("input: %b-%b-%b",aSign,aExp,aSig);
			$display("z0Sign:%b z0Sig:%b z0Exp:%b s0:%b",z0Sign,z0Sig,z0Exp,s0);
			$display("zSign:%b  zSig :%b zExp :%b yS:%b %b",zSign,zSig, zExp, yS, status);
			$display("zxSig:%b zxExp:%b",zxSig, zxExp);
			$display("use_fast_r :%b ", I.sqrt.use_fast_r);
			$finish();
		end
	end
end

always @(negedge clk) begin
	logic [SIG_W+EXP_W:0] a_nxt,z0_nxt;
	logic [4:0] s0pre_nxt;
	if(reset) begin
		readcount = $fscanf(fd, "DUMP: %x %x %x", a_nxt, z0_nxt, s0pre_nxt);
		a<=a_nxt; z0<=z0_nxt; s0pre<=s0pre_nxt;
		$display("New data:  %h %h %b", a_nxt, z0_nxt, s0pre_nxt);
		if(readcount != 3) $display("Read Error! %d", readcount);
	end
	else begin
		if(done) begin
			readcount = $fscanf(fd, "DUMP: %x %x %x", a_nxt, z0_nxt, s0pre_nxt);
			a<=a_nxt; z0<=z0_nxt; s0pre<=s0pre_nxt;
			if(readcount != 3) begin
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

