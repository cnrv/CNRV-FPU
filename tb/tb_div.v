
module tb_div(input clk, reset, 
/* verilator lint_off UNUSED */
	input [2:0] rnd);
/* verilator lint_on UNUSED */

parameter W=10;

logic [W-1:0] N,D, Quo,Rem;
logic done,strobe;

R5FP_int_div_sqrt #(.W(W)) I (
	.N_i(N), .D_i(D),
	.is_div_i(1'b1),
	.strobe_i(strobe),
	.Quo_o(Quo), .Rem_o(Rem),
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
		N<=1;
		D<=2;
	end
	else begin
		if(stop) begin
			$display("All Done");
			$finish();
		end
		if(done) begin
			if(D==N) begin
				if((&D[W-2:0])==1) stop<=1'b1;
				N<=1;
				D<=D+1;
			end
			else begin
				N<=N+1;
			end
		end
	end
end

always @(posedge clk) begin
	if(reset) strobe<=1'b1;
	else if (strobe) strobe<=1'b0;
	else if (done) strobe<=1'b1;
end

logic [2*W-1:0] prod,t1,t2;
/* verilator lint_off BLKSEQ */
always @(negedge clk) begin
	if(done&&!reset) begin
		reg pass;
		prod=Quo*D+{{W{1'b0}},Rem};
		t1=Quo*D;
		t2=Quo*D-{{W{1'b0}},Rem};
		pass=(prod[2*W-1:W]==N);

		if(pass) begin
			//$display("Pass");
		end
		else begin
			$display("Fail!!");
			$display("N:%b  D:%b  Quo:%b  Rem:%b  Prod:%b %b %b", 
				N,D,Quo,Rem,prod,t1,t2);
			$finish();
		end
	end
end
/* verilator lint_on BLKSEQ */

endmodule

