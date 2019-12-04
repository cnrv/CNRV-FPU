

`include "R5FP_inc.vh"

/* verilator lint_off UNUSED */
/* verilator lint_off WIDTH */
/* verilator lint_off VARHIDDEN */
`include "../sim_ver/DW_fp_div.v"
/* verilator lint_on UNUSED */
/* verilator lint_on WIDTH */
/* verilator lint_on VARHIDDEN */

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
logic [EXP_W:0] xExp, tailZeroCnt;
logic [SIG_W+3-1:0] xSig;
logic [5:0] xMidStatus;
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
		.tailZeroCnt_o(tailZeroCnt),
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
		.tailZeroCnt(tailZeroCnt),
		.aStatus(xMidStatus),
		.aSig({1'b0,xSig}),
		.rnd(rnd),
		.aSign(xMidStatus[`SIGN]),
		.zToInf(1'b0),
		.specialTiny(1'b0),
		.z(zx),
		.zStatus(zStatus));

R5FP_exp_decr #(
	.SIG_W(SIG_W),
	.EXP_W(EXP_W)) exp_decr (.a(use_fast? x_fast : zx), .z(z_o));

assign status_o=use_fast? xStatus_fast : zStatus;

endmodule

///////////////////////////////////////////////////////////////////

module tb_fdiv(input clk, reset, input [2:0] rnd);

parameter SIG_W=5;
parameter EXP_W=4;

logic done,strobe;
logic bSign;
logic [7:0] status,status0pre,status0;
logic [SIG_W-1:0] aSig,bSig,zSig0,zSig,zxSig;
logic [EXP_W-1:0] aExp,bExp,zExp0,zExp;
logic [EXP_W:0] zxExp;
/* verilator lint_off UNUSED */
logic zSign0,zSign,zxSign;
/* verilator lint_on UNUSED */

DW_fp_div #(
	.sig_width(SIG_W),
	.exp_width(EXP_W),
	.ieee_compliance(1)) R (
		.a({1'b0,aExp,aSig}),
		.b({bSign,bExp,bSig}),
		.rnd(to_snps_rnd(rnd)), 
		.z({zSign0,zExp0,zSig0}), 
		.status(status0pre));

R5FP_div_wrap #(
	.EXP_W(EXP_W),
	.SIG_W(SIG_W)) I (
	.a_i({1'b0,aExp,aSig}),
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

/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if(done&&!reset) begin
		reg pass;
		status0=status0pre;
		if(zExp0!=0||zSig0!=0) status0[`Z_TINY]=0; //fix a bug of designware!

		pass=(zSig0==zSig && zExp0==zExp && status0==status);
		if((&zExp0)==1&&(&zExp)==1&&zSig0!=0&&zSig!=0) pass=1; //both are NaN

		if(pass) begin
			//$display("Pass");
			//$display("Input: a:%b-%b b:%b-%b",aExp,aSig,bExp,bSig);
			//$display("zSig :%b zExp :%b status :%b",zSig, zExp, status);
			//$display("------");
		end
		else begin
			$display("Fail!! %d", $time);
			$display("Input: a:%b-%b b:%b-%b-%b",aExp,aSig,bSign,bExp,bSig);
			$display("zSig0:%b zExp0:%b status0:%b",zSig0,zExp0,status0);
			$display("zSig :%b zExp :%b status :%b",zSig, zExp, status);
			$display("xExp:%b(max:%b) xSig:%b x_fast:%b exp_decr.a:%b use_fast:%b", 
					I.xExp, `EXP_NORMAL_MAX(EXP_W), I.xSig, I.x_fast, I.exp_decr.a, I.use_fast);
			$display("zxSig:%b zxExp:%b",zxSig, zxExp);
			$display("use_fast_r :%b ", I.div.use_fast_r);
			$finish();
		end
	end
end
/* verilator lint_on BLKSEQ */

reg stop;
always @(negedge clk) begin
	if(reset) begin
		stop<=1'b0;
		//aExp<={EXP_W{1'b1}};
		//aSig<=0;
		//{bExp,bSig}<=0;

		//aExp<=0; bExp<=0;
		//aSig<=1; bSig<=1;

		//aExp<=0; bExp<=5'b00111;
		//aSig<=0; bSig<=2;

		//aExp<={EXP_W{1'b1}}; bExp<=7;
		//aSig<={SIG_W{1'b1}}; bSig<={SIG_W{1'b1}};

		//aExp<=0; bExp<=9;
		//aSig<=1; bSig<=0;

		aExp<=0; bExp<=7;
		aSig<=0; bSig<=0;
	end
	else begin
		if(stop) begin
			$display("All Done");
			$stop();
		end
		if(done) begin
			logic [SIG_W-1:0] aSig_nxt,bSig_nxt;
			logic [EXP_W-1:0] aExp_nxt,bExp_nxt;
			logic bSign_nxt;
			{bExp_nxt,bSig_nxt}={bExp,bSig};
			if((&{aExp[EXP_W-1:0],aSig})==1) begin
				if((&{bExp[EXP_W-1:0],bSig,bSign})==1) stop<=1'b1;
				{bExp_nxt,bSig_nxt,bSign_nxt}={bExp,bSig,bSign}+1;
				bExp<=bExp_nxt;
				bSig<=bSig_nxt;
				bSign<=bSign_nxt;
				if(bSig_nxt==1&&bSign_nxt==0) begin
					$display("%d New B input: %b-%b-%b",$time, bSign_nxt,bExp_nxt,bSig_nxt);
				end
			end
			{aExp_nxt,aSig_nxt}={aExp,aSig}+1;
			aExp<=aExp_nxt;
			aSig<=aSig_nxt;
			//$display("%d New input: a:%b-%b b:%b-%b",$time, aExp_nxt,aSig_nxt,bExp_nxt,bSig_nxt);
		end
	end
end

always @(posedge clk) begin
	if(reset) strobe<=1'b1;
	else if (strobe) strobe<=1'b0;
	else if (done) strobe<=1'b1;
end


endmodule

