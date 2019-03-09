
module R5FP_int_div_sqrt #(parameter W=6) (
	input [W-1:0] N_i,D_i, 
	input strobe_i, is_div_i,
	output [W-1:0] Quo_o, Rem_o,
	output reg done_o,
	output ready_o,
	input clk,reset);

localparam CW=$clog2(W)-1;

reg is_div_r;
always @(posedge clk) if(strobe_i) is_div_r<=is_div_i;

reg [W-1:0] D_r;
reg [W+1:0] P_r;
reg [CW-1:0] counter;
reg [W-1:0] Q_r;
reg idle_r;
assign ready_o=idle_r;
assign Quo_o={W{done_o}}&Q_r;
assign Rem_o=is_div_r?  P_r[W-1:0] :
	 { {(W-1){1'b0}}, Quo_o!=~({W{done_o}}&P_r[W:1])};

reg [W+1:0] nextP_a, nextP_b, nextP_c;
reg [W+1:0] nnP1_a, nnP1_b, nnP1_c, nnP1_d;
reg [W+1:0] nnP0_a, nnP0_b, nnP0_c, nnP0_d;
wire [W+1:0] nextP=nextP_a+nextP_b+nextP_c;
wire [W+1:0] nnP1=nnP1_a+nnP1_b+nnP1_c+nnP1_d;
wire [W+1:0] nnP0=nnP0_a+nnP0_b+nnP0_c+nnP0_d;
/* verilator lint_off WIDTH */
always @(*) begin
	if(is_div_r) begin
		//nextP={P_r,1'b0} - D_r;
		//nnP1={P_r,2'b0} - {D_r,1'b0} - D_r;
		//nnP0={P_r,2'b0} - D_r;
		nextP_a={P_r,1'b0}; nextP_b=~D_r; nextP_c=1;
		nnP1_a={P_r,2'b0};  nnP1_b=~{D_r,1'b0};
		nnP1_c=~D_r;        nnP1_d=2;
		nnP0_a={P_r,2'b0};  nnP0_b=~D_r;
		nnP0_c=0; nnP0_d=1;
	end
	else begin
		nextP_a={P_r,2'b0}; nextP_c=D_r[W-1:W-2]; nextP_b={P_r[W+1] ? Q_r : ~Q_r, 2'b11};
		nnP1_a={P_r,4'b0};           nnP1_b={P_r[W+1] ? Q_r : ~Q_r, 4'b1100};
		nnP1_c={Q_r[W-2:0],3'b011};  nnP1_d=D_r[W-1:W-4];
		nnP0_a={P_r,4'b0};           nnP0_b={P_r[W+1] ? Q_r : ~Q_r, 4'b1100};
		nnP0_c={~Q_r[W-2:0],3'b011}; nnP0_d=D_r[W-1:W-4];
	end
end
/* verilator lint_on WIDTH */

always @(posedge clk) begin
	assert(W%2==0);
	if(reset) begin
		counter<=0;
	end
	else if(strobe_i) begin
		if(is_div_i) begin
			P_r[W-1:0]<=N_i;
			D_r<=D_i;
			Q_r<={W{1'b0}};
			counter<=0;
			//$display("Input N:%b D:%b", N_i, D_i);
		end
		else begin
			P_r<=0;
			D_r<=D_i;
			if(!reset) assert(D_i[W-1]==1'b0);
			Q_r<={W{1'b0}};
			counter<=0;
			//$display("INT Input D:%b", D_i);
		end
	end
	else if(!idle_r) begin
		if(is_div_r) begin
			reg [W-1:0] nnP,nnQ;
			reg [W-2:0] nextQ;
			nextQ={Q_r[W-3:0], nextP[W-1]==1'b0};
			if(nextP[W-1]==1'b0) begin
				nnP=(nnP1[W-1]==1'b0)? nnP1[W-1:0] : {nextP[W-2:0],1'b0};
				nnQ={nextQ[W-2:0], nnP1[W-1]==1'b0};
			end
			else begin
				nnP=(nnP0[W-1]==1'b0)? nnP0[W-1:0] : {P_r[W-3:0],2'b0};
				nnQ={nextQ[W-2:0], nnP0[W-1]==1'b0};
			end
			Q_r<=nnQ;
			P_r[W-1:0]<=nnP;
			counter<=counter+1;
			//$display("Now P:%b->%b Q:%b->", P_r,nnP,Q_r,nnQ);
		end
		else begin
			reg [W+1:0] nnP;
			reg [W-1:0] nnQ;

			if(nextP[W+1]) begin
				nnP=nnP1;
				nnQ={Q_r[W-3:0],1'b0,~nnP1[W+1]};
			end
			else begin
				nnP=nnP0;
				nnQ={Q_r[W-3:0],1'b1,~nnP0[W+1]};
			end
			P_r<=nnP;
			Q_r<=nnQ;
			counter<=counter+1;
			D_r<=D_r<<4;
			//$display("INT Now D_r:%b(%d) P:%b(%d)->%b(%d) q:%b(%d)->%b(%d) %b %b", 
			//	D_r,D_r,P_r,P_r,nnP,nnP,Q_r,Q_r,nnQ,nnQ, nnQ,~nnP[W:1]);
		end
	end	
end

always @(posedge clk) begin
	if(reset) begin
		done_o<=1'b0;
		idle_r<=1'b1;
	end
	else if(strobe_i) begin
		done_o<=1'b0;
		idle_r<=1'b0;
	end
	else if(done_o) begin
		done_o<=1'b0;
	end
	/* verilator lint_off WIDTH */
	else if(counter==W/2-1) begin
		done_o<=1'b1;
		idle_r<=1'b1;
	end
	/* verilator lint_on WIDTH */
end

endmodule
