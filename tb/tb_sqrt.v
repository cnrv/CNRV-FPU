
module tb_sqrt(input clk, reset, 
/* verilator lint_off UNUSED */
	input [2:0] rnd);
/* verilator lint_on UNUSED */

parameter W=8;

logic [W-1:0] D;
logic [W-1:0] Quo;
logic [W-1:0] Rem;
logic done,strobe;

R5FP_int_div_sqrt #(.W(W)) I (
	.D_i(D),
	.N_i({W{1'b0}}),
	.strobe_i(strobe),
	.is_div_i(1'b0),
	.Quo_o(Quo),
	.Rem_o(Rem),
	.done_o(done),
	/* verilator lint_off PINCONNECTEMPTY */
	.ready_o(),
	/* verilator lint_on PINCONNECTEMPTY */
	.clk(clk),
	.reset(reset));

reg stop;
always @(negedge clk) begin
	if(reset) begin
		stop<=1'b0;
		D<=8'b0010_0000;
		//D<={12'b0100_0000_0000,4'b0};
	end
	else begin
		if(stop) begin
			$display("All Done");
			$stop();
		end
		if(done) begin
			if((&D[W-2:0])==1) stop<=1'b1;
			D<=D+1;
		end
	end
end

always @(posedge clk) begin
	if(reset) strobe<=1'b1;
	else if (strobe) strobe<=1'b0;
	else if (done) strobe<=1'b1;
end

logic [2*W-1:0] prod,prod2;
/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if(done&&!reset) begin
		reg pass;
		prod=Quo*Quo;
		prod2=Quo*Quo+2*Quo+1;
		pass=(prod<={D,{W{1'b0}}} && {D,{W{1'b0}}}<prod2);
		if(prod=={D,{W{1'b0}}}) pass=(Rem==0);

		if(pass) begin
			//$display("Pass");
			//$display("D:%b  Quo:%b Rem:%b Prod:%b-%b %b-%b", 
			//	D,Quo,Rem,prod[2*W-1:W],prod[W-1:0],prod2[2*W-1:W],prod2[W-1:0]);
		end
		else begin
			$display("Fail!!");
			$display("D:%b  Quo:%b Rem:%b Prod:%b-%b %b-%b", 
				D,Quo,Rem,prod[2*W-1:W],prod[W-1:0],prod2[2*W-1:W],prod2[W-1:0]);
			$display("Why? %b %b", ~Rem, Quo);
			$finish();
		end
	end
end
/* verilator lint_on BLKSEQ */

endmodule

