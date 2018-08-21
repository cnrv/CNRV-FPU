
`define DEBUG $display
`define FUNC_POSTPROC func_postproc

module R5FP_postproc_core #(
		parameter I_SIG_W=25,
		parameter SIG_W=23,
		parameter EXP_W=9) (
		input [EXP_W-1:0] aExp,
		input [6-1:0] aStatus,
/* verilator lint_off UNUSED */
		input [I_SIG_W-1:0] aSig,
/* verilator lint_on UNUSED */
		input  [2:0] rnd,
		input aSign,
		input [EXP_W-1:0] tailZeroCnt,
		output specialZRnd,
		output reg [SIG_W+EXP_W:0] z,
		output reg [7:0] zStatus);

reg sticky, round_bit, guard_bit;
reg useMinValue;
wire specialRnd=(aSig[I_SIG_W-SIG_W-2:I_SIG_W-SIG_W-3]==2'b10);
reg specialZ;
assign specialZRnd=specialZ&&specialRnd;
always @(*) begin
	reg [EXP_W+2:0] aExpExt;
	reg signed [I_SIG_W:0] aSig2;
	reg [SIG_W-1:0] zeroSig;
	reg [SIG_W-1:0] oneSig;
	reg [EXP_W-1:0] zeroExp,minExp;
	reg [EXP_W-1:0] allOnesExp;
	reg [I_SIG_W+SIG_W:0] aSig3,rnd_bits,aSig3Tail,aSig4;
	reg [SIG_W-1:0] mask;
	reg [SIG_W-1:0] zSig;
	reg roundCarry,needShift;
	// variable initialization
	specialZ=0;
	useMinValue=0;
	zeroSig = 0;
	oneSig = 0;
	oneSig[0] = 1'b1;
	zeroExp = 0;
	minExp = `EXP_DENORMAL_MIN(EXP_W-1,SIG_W);
	allOnesExp = {EXP_W{1'b1}};
	zStatus = 0;
	aSig3 = 0;
	z = 0;
	rnd_bits = 0;
	mask = 0;

	zStatus = 0;
	zStatus[`Z_IS_ZERO] = aStatus[`IS_ZERO];
	zStatus[`Z_IS_INF] = aStatus[`IS_INF];
`ifdef FORCE_DW_NAN_BEHAVIOR
	zStatus[`Z_INVALID] = aStatus[`IS_NAN];
`else
	zStatus[`Z_INVALID] = aStatus[`INVALID];
`endif
	zStatus[`Z_INEXACT] = aStatus[`STICKY];
	  
	//if(aSig[I_SIG_W-1:I_SIG_W-2]!=2'b01) begin
	//	$display("Error! leading two bits of aSig is not 01!!");
	//end
	aSig2 = {2'b01,aSig[I_SIG_W-3:0],1'b0};
	if (zStatus[`Z_IS_ZERO] || zStatus[`Z_IS_INF] || aStatus[`IS_NAN]) begin
		if (zStatus[`Z_IS_ZERO] == 1 && aStatus[`IS_NAN] == 0) begin
			if (zStatus[`Z_INEXACT] == 1) begin
				if ((rnd == `RND_DOWN && aStatus[`SIGN] == 1) ||
					(rnd == `RND_UP && aStatus[`SIGN] == 0) ||
					rnd == `RND_FROM_ZERO) begin
					z = {aStatus[`SIGN], zeroExp, oneSig};
					zStatus[`Z_IS_ZERO] = 1'b0;
					zStatus[`Z_TINY] = 0;
					//`DEBUG("HereJ");
				end
				else begin
					z = {aStatus[`SIGN], zeroExp, zeroSig};
					zStatus[`Z_IS_ZERO] = 1'b1;
					zStatus[`Z_TINY] = 1'b1;
					//`DEBUG("HereI");
				end
			end
			else begin
				z = {aStatus[`SIGN], zeroExp, zeroSig};
				//`DEBUG("HereH");
			end
		end
		
		if (aStatus[`IS_NAN] == 1'b1) begin
			logic[I_SIG_W-4:I_SIG_W-SIG_W-2] tmpZero;
			tmpZero=0;
			zStatus[`Z_IS_ZERO] = 1'b0;
			zStatus[`Z_IS_INF] = 1'b0;
			zStatus[`Z_INEXACT] = 1'b0;
			z = {1'b0, allOnesExp, 1'b1, tmpZero};
			//`DEBUG("HereG aSign:%b zStatus:%b",aSign,zStatus);
		end
		else if (zStatus[`Z_IS_INF] == 1'b1) begin
			z = {aStatus[`SIGN], allOnesExp, zeroSig};
			zStatus[`Z_IS_ZERO] = 1'b0;
			zStatus[`Z_INEXACT] = 1'b0;
			//`DEBUG("HereF");
		end
	end
	else begin
		sticky = zStatus[`Z_INEXACT];
		aExpExt = {3'b0,aExp}; //$unsigned(aExp);
		
		aSig3 = { {SIG_W{1'b0}}, aSig2 } << SIG_W;
		
		aSig3Tail=aSig3>>tailZeroCnt;
		sticky = (|aSig3Tail[I_SIG_W-1-1-1:0]) || sticky;
		round_bit = aSig3Tail[I_SIG_W-1-1];
		guard_bit = aSig3Tail[I_SIG_W-1];
		//`DEBUG("Here5 aExp:%b aSig:%b aSig2:%b aSig3:%b tailZeroCnt:%d aSig3Tail:%b sticky:%b aSig3Tail[I_SIG_W-1-1-1:0]:%b guard_bit:%b round_bit:%b aStatus:%b zStatus:%b", aExp, aSig,aSig2,aSig3,tailZeroCnt,aSig3Tail, sticky, aSig3Tail[I_SIG_W-1-1-1:0],guard_bit,round_bit,aStatus,zStatus);
		
		roundCarry = getRoundCarry(rnd, aSign, guard_bit, round_bit, sticky);
		rnd_bits[0] = roundCarry;
		rnd_bits = rnd_bits<<(I_SIG_W-1);
		rnd_bits = rnd_bits<<tailZeroCnt;
		//`DEBUG("Here5 %d aSig3:%b rnd_bits:%b",$time,aSig3,rnd_bits);
		aSig4 = aSig3+rnd_bits;
		//`DEBUG("Here5 aSig4:%b aSig4[I_SIG_W+SIG_W-1:I_SIG_W-1]:%b",aSig4,aSig4[I_SIG_W+SIG_W-1:I_SIG_W-1]);

		mask=({SIG_W{1'b1}}<<tailZeroCnt);
  
		needShift=aSig4[I_SIG_W+SIG_W];
		if ( needShift ) begin
			aExpExt = aExpExt + 1;
			aSig4 = aSig4 >> 1;
		end
		zSig=aSig4[I_SIG_W+SIG_W-2:I_SIG_W-1];
    
		if (((aExpExt==0) && ((sticky == 1'b1) || (aSig2 != 0)))  ||
			((aExpExt==1) && (aSig4[I_SIG_W+SIG_W:I_SIG_W+SIG_W-1]==0)&&
			((sticky == 1'b1) || (aSig2 != 0)))) begin
			zStatus[`Z_INEXACT] = 1'b1;
			if ((rnd == `RND_DOWN && aSign == 1) ||
				(rnd == `RND_UP && aSign == 0) ||
				rnd == `RND_FROM_ZERO) begin
				zStatus[`Z_IS_ZERO] = 1'b0;
				zStatus[`Z_TINY] = 1'b1;
				z = {aSign, minExp, oneSig};
				//`DEBUG("HereE");
			end
			else begin
				zStatus[`Z_IS_ZERO] = 1'b1;
				zStatus[`Z_TINY] = 1'b1;
				z = {aSign, zeroExp, zeroSig};
				//`DEBUG("HereD zStatus:%b aStatus:%b",zStatus,aStatus);
			end
		end
		else begin
			zStatus[`Z_INEXACT] = zStatus[`Z_INEXACT]|round_bit|sticky;
			if(aExpExt<`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)) begin
				//`DEBUG("HereC0 aExpExt%b %b sticky:%b asig3:%b",aExpExt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W), sticky,aSig3[I_SIG_W+SIG_W-2:0]);
				if( rnd==`RND_NEAREST_EVEN && aExpExt==`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-1 && aSig3[I_SIG_W+SIG_W-2:0]!=0 && !needShift) begin
					useMinValue=1;
				end
				if( rnd==`RND_NEAREST_UP && aExpExt==`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-1 && !needShift ) begin
					useMinValue=1;
				end
				if( rnd==`RND_FROM_ZERO || (rnd==`RND_DOWN && aSign) || (rnd==`RND_UP && !aSign) ) begin
					useMinValue=1;
				end

				zStatus[`Z_INEXACT] = 1'b1;
				if(useMinValue) begin
					zStatus[`Z_IS_ZERO] = 1'b0;
`ifdef FORCE_DW_DIV_BEHAVIOR
					zStatus[`Z_TINY] = 1'b0;
`else
					zStatus[`Z_TINY] = 1'b1;
`endif
					aExpExt=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W);
					z = {aSign, aExpExt[EXP_W-1:0], oneSig};
				end
				else begin
					zStatus[`Z_IS_ZERO] = 1'b1;
					zStatus[`Z_TINY] = 1'b1;
					z = {aSign, zeroExp, zeroSig};
				end
				//`DEBUG("HereC aExpExt%b %b asig4: %b %b",aExpExt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),aSig4[I_SIG_W+SIG_W-1], aSig4[I_SIG_W+SIG_W-2:0]);
			end
			else if(aExpExt>`EXP_NORMAL_MAX(EXP_W-1)) begin
				if(/*aExpExt==`EXP_NORMAL_MAX(EXP_W-1)+1 && zSig==0 &&*/
				(rnd==`RND_TO_ZERO || (rnd==`RND_DOWN && !aSign) || (rnd==`RND_UP && aSign) ) ) begin
					zStatus[`Z_INEXACT] = 1'b1;
					zStatus[`Z_HUGE] = 1'b1;
					aExpExt=`EXP_NORMAL_MAX(EXP_W-1);
					z = {aSign, aExpExt[EXP_W-1:0], {SIG_W{1'b1}} };
				end
				else begin
					zStatus[`Z_INEXACT] = 1'b1;
					zStatus[`Z_IS_INF] = 1'b1;
					zStatus[`Z_HUGE] = 1'b1;
					z = {aSign, {EXP_W{1'b1}}, zeroSig};
				end
				//`DEBUG("HereB aExpExt%b %b zSig:%b zStatus:%b",aExpExt,`EXP_NORMAL_MAX(EXP_W-1), zSig, zStatus);
			end
			else begin
				zSig=zSig&mask;
				z = {aSign,aExpExt[EXP_W-1:0],zSig};
				//`DEBUG("HereA z:%b round_bit:%b sticky:%b aExpExt:%b %b mask:%b aSig3:%b aSig2:%b zSig:%b inExact:%b", z,round_bit,sticky, aExpExt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),mask,aSig3,aSig2,zSig,zStatus[`Z_INEXACT]);
`ifdef FORCE_DW_MULT_BEHAVIOR
				if(aExpExt<=`EXP_DENORMAL_MAX(EXP_W-1))  begin
					zStatus[`Z_TINY] = 1'b1;
				end
`else
`ifdef FORCE_DW_DIV_BEHAVIOR
				/*do nothing*/
`else
				if(zStatus[`Z_INEXACT]&&aExpExt<=`EXP_DENORMAL_MAX(EXP_W-1))  begin
					zStatus[`Z_TINY] = 1'b1;
				end
				//very special case about exiting denormal format
				if(aExpExt==`EXP_DENORMAL_MAX(EXP_W-1)+1&&zSig==0) begin
					specialZ=1;
					//`DEBUG("HereX: grt:%b%b%b",guard_bit,round_bit,sticky);
					if(rnd==`RND_NEAREST_EVEN||rnd==`RND_NEAREST_UP) begin
						zStatus[`Z_TINY]|={guard_bit,round_bit,sticky}==3'b110;
					end
					if(rnd==`RND_DOWN||rnd==`RND_UP) begin
						zStatus[`Z_TINY]|={round_bit,sticky}<=2'b10&&guard_bit;
					end
				end
`endif
`endif
			end
		end
	end
	////`DEBUG("Here z:%b aExp:%b aSig:%b  aExpExt:%b aSig3:%b aStatus:%b",z,aExp,aSig,aExpExt,aSig3,aStatus);
	////`DEBUG("Here %b %b   %b %b",`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),`EXP_DENORMAL_MAX(EXP_W-1),`EXP_NORMAL_MIN(EXP_W-1),`EXP_NORMAL_MAX(EXP_W-1));
end

endmodule

module R5FP_postproc #(
	parameter I_SIG_W=25,
	parameter SIG_W=23,
	parameter EXP_W=9) (
	input [EXP_W-1:0] aExp,
	input [6-1:0] aStatus,
	input [I_SIG_W-1:0] aSig,
	input aSign,
	input  [2:0] rnd,
	output specialZRnd,
	output reg [SIG_W+EXP_W:0] z,
	output reg [7:0] zStatus);

reg [EXP_W-1:0] tailZeroCnt;
always @(*) begin
	tailZeroCnt=0;
	if(aExp>=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W) && aExp<=`EXP_DENORMAL_MAX(EXP_W-1)) begin
		tailZeroCnt=1+(`EXP_DENORMAL_MAX(EXP_W-1)-aExp);
	end
end

R5FP_postproc_core #(
		.I_SIG_W(I_SIG_W),
		.SIG_W(SIG_W),
		.EXP_W(EXP_W)) core (
	.aExp(aExp),
	.aStatus(aStatus),
	.aSig(aSig),
	.rnd(rnd),
	.aSign(aSign),
	.tailZeroCnt(tailZeroCnt),
	.specialZRnd(specialZRnd),
	.z(z),
	.zStatus(zStatus));
	
endmodule

`undef DEBUG
`undef FUNC_POSTPROC
