
`define DEBUG $display

function void `FUNC_POSTPROC(
        input [EXP_W-1:0] aExp,
        input [7-1:0] aStatus,
        input [I_SIG_W-1:0] aSig,
        input  [2:0] rnd,
		input aSign,
        input [EXP_W-1:0] tailZeroCnt,
        output reg [SIG_W+EXP_W:0] z,
        output reg [7:0] status);

    reg [EXP_W+2:0] aExpExt;
    reg signed [I_SIG_W:0] aSig2;
    reg [SIG_W-1:0] zeroSig;
    reg [SIG_W-1:0] oneSig;
    reg [EXP_W-1:0] zeroExp;
    reg [EXP_W-1:0] allOnesExp;
    reg [I_SIG_W+SIG_W:0] aSig3,rnd_bits,aSig3Tail,aSig4;
    reg [SIG_W-1:0] mask;
    reg sticky, round_bit, guard_bit;
    reg [EXP_W-1:0] oneExp;
    reg [SIG_W-1:0] zSig;
    integer i;
    reg roundCarry,needShift,useMinValue;
    // variable initialization
    zeroSig = 0;
    oneSig = 0;
    oneSig[0] = 1'b1;
    zeroExp = 0;
    allOnesExp = ~0;
    status = 0;
    oneExp = 1;
    aSig3 = 0;
    z = 0;
    rnd_bits = 0;
	mask = 0;
	useMinValue=0;    

    status = 0;
    status[`Z_IS_ZERO] = aStatus[`IS_ZERO];
    status[`Z_IS_INF] = aStatus[`IS_INF];
    status[`Z_INVALID] = aStatus[`IS_NAN];
    status[`Z_INEXACT] = aStatus[`STICKY];
      
	if(aSig[I_SIG_W-1:I_SIG_W-2]!=2'b01) begin
		$display("Error! leading two bits of aSig is not 01!!");
	end
    aSig2 = {2'b01,aSig[I_SIG_W-3:0],1'b0};
    if (status[`Z_IS_ZERO] || status[`Z_IS_INF] || status[`Z_INVALID]) begin
        if (status[`Z_IS_ZERO] == 1 && status[`Z_INVALID] == 0) begin
            if (status[`Z_INEXACT] == 1) begin
                if ((rnd == `RND_DOWN && aStatus[`SIGN] == 1) ||
                    (rnd == `RND_UP && aStatus[`SIGN] == 0) ||
                    rnd == `RND_FROM_ZERO) begin
                    z = {aStatus[`SIGN], zeroExp, oneSig};
                    status[`Z_IS_ZERO] = 1'b0;
                    status[`Z_TINY] = 0;
					//`DEBUG("HereJ");
                end
                else begin
                    z = {aStatus[`SIGN], zeroExp, zeroSig};
                    status[`Z_IS_ZERO] = 1'b1;
                    status[`Z_TINY] = 1'b1;
					//`DEBUG("HereI");
                end
            end
            else begin
             	z = {aStatus[`SIGN], zeroExp, zeroSig};
				//`DEBUG("HereH");
            end
        end

        if (status[`Z_INVALID] == 1'b1) begin
            status = {8{1'b0}};
            status[`Z_IS_INF] = 1'b0;
            status[`Z_INVALID] = 1'b1;
            z = {aSign, allOnesExp, aSig[I_SIG_W-3:I_SIG_W-SIG_W-2]};
			//`DEBUG("HereG aSign:%b",aSign);
        end
        else if (status[`Z_IS_INF] == 1'b1) begin
            z = {aStatus[`SIGN], allOnesExp, zeroSig};
            status[`Z_IS_ZERO] = 1'b0;
            status[`Z_INEXACT] = 1'b0;
			//`DEBUG("HereF");
        end
    end
    else begin
        sticky = status[`Z_INEXACT];
        aExpExt = $unsigned(aExp);

        aSig3 = aSig2 << SIG_W;
    
		aSig3Tail=aSig3>>tailZeroCnt;
        sticky = (|aSig3Tail[I_SIG_W-1-1-1:0]) || sticky;
        round_bit = aSig3Tail[I_SIG_W-1-1];
        guard_bit = aSig3Tail[I_SIG_W-1];
		//`DEBUG("Here5 aSig:%b aSig2:%b aSig3:%b tailZeroCnt:%d aSig3Tail:%b sticky:%b aSig3Tail[I_SIG_W-1-1-1:0]:%b guard_bit:%b round_bit:%b", aSig,aSig2,aSig3,tailZeroCnt,aSig3Tail, sticky, aSig3Tail[I_SIG_W-1-1-1:0],guard_bit,round_bit);

        roundCarry = getRoundCarry(rnd, aSign, guard_bit, round_bit, sticky);
        rnd_bits[0] = roundCarry;
		rnd_bits = rnd_bits<<(I_SIG_W-1);
		rnd_bits = rnd_bits<<tailZeroCnt;
		//`DEBUG("Here5 aSig3:%b rnd_bits:%b",aSig3,rnd_bits);
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
            status[`Z_INEXACT] = 1'b1;
			if ((rnd == `RND_DOWN && aSign == 1) ||
				(rnd == `RND_UP && aSign == 0) ||
				rnd == `RND_FROM_ZERO) begin
                status[`Z_IS_ZERO] = 1'b0;
                status[`Z_TINY] = 1'b0;
                z = {aSign, zeroExp, oneSig};
				//`DEBUG("HereE");
            end
            else begin
                status[`Z_IS_ZERO] = 1'b1;
                status[`Z_TINY] = 1'b1;
                z = {aSign, zeroExp, zeroSig};
				//`DEBUG("HereD status:%b aStatus:%b",status,aStatus);
            end
        end
        else begin
            status[`Z_INEXACT] = status[`Z_INEXACT]|round_bit|sticky;
			if(aExpExt<`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)) begin
				//`DEBUG("HereC0 aExpExt%b %b sticky:%b asig3:%b",aExpExt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W), sticky,aSig3[I_SIG_W+SIG_W-2:0]);
				if( rnd==`RND_NEAREST_EVEN && aExpExt==`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-1 && aSig3[I_SIG_W+SIG_W-2:0]!=0 && !needShift)
					useMinValue=1;
				if( rnd==`RND_NEAREST_UP && aExpExt==`EXP_DENORMAL_MIN(EXP_W-1,SIG_W)-1 && !needShift ) 
					useMinValue=1;
				if( rnd==`RND_FROM_ZERO || (rnd==`RND_DOWN && aSign) || (rnd==`RND_UP && !aSign) )
					useMinValue=1;

				if(useMinValue) begin
					status[`Z_INEXACT] = 1'b1;
					status[`Z_TINY] = 1'b1;
					status[`Z_IS_ZERO] = 1'b0;
					aExpExt=`EXP_DENORMAL_MIN(EXP_W-1,SIG_W);
					z = {aSign, aExpExt[EXP_W-1:0], oneSig};
				end
				else begin
					status[`Z_INEXACT] = 1'b1;
					status[`Z_TINY] = 1'b1;
					status[`Z_IS_ZERO] = 1'b1;
					z = {aSign, zeroExp, zeroSig};
				end
				//`DEBUG("HereC aExpExt%b %b asig4: %b %b",aExpExt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),aSig4[I_SIG_W+SIG_W-1], aSig4[I_SIG_W+SIG_W-2:0]);
			end
			else if(aExpExt>`EXP_NORMAL_MAX(EXP_W-1)) begin
				if(/*aExpExt==`EXP_NORMAL_MAX(EXP_W-1)+1 && zSig==0 &&*/
				(rnd==`RND_TO_ZERO || (rnd==`RND_DOWN && !aSign) || (rnd==`RND_UP && aSign) ) ) begin
					status[`Z_INEXACT] = 1'b1;
					status[`Z_HUGE] = 1'b1;
					aExpExt=`EXP_NORMAL_MAX(EXP_W-1);
					z = {aSign, aExpExt[EXP_W-1:0], {SIG_W{1'b1}} };
				end
				else begin
					status[`Z_INEXACT] = 1'b1;
					status[`Z_IS_INF] = 1'b1;
					status[`Z_HUGE] = 1'b1;
					z = {aSign, {EXP_W{1'b1}}, zeroSig};
					//`DEBUG("HereB aExpExt%b %b zSig:%b status:%b",aExpExt,`EXP_NORMAL_MAX(EXP_W-1), zSig, status);
				end
			end
			else begin
				zSig=zSig&mask;
				z = {aSign,aExpExt[EXP_W-1:0],zSig};
				//`DEBUG("HereA z:%b round_bit:%b sticky:%b aExpExt:%b %b mask:%b aSig3:%b zSig:%b ", z,round_bit,sticky, aExpExt,`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),mask,aSig3,zSig);
`ifdef FORCE_DW_MULT_BEHAVIOR
				if(aExpExt<=`EXP_DENORMAL_MAX(EXP_W-1)) status[`Z_TINY] = 1'b1;
`endif
			end
        end
    end
    //`DEBUG("Here z:%b aExp:%b aSig:%b  aExpExt:%b aSig3:%b aStatus:%b",z,aExp,aSig,aExpExt,aSig3,aStatus);
    //`DEBUG("Here %b %b   %b %b",`EXP_DENORMAL_MIN(EXP_W-1,SIG_W),`EXP_DENORMAL_MAX(EXP_W-1),`EXP_NORMAL_MIN(EXP_W-1),`EXP_NORMAL_MAX(EXP_W-1));

endfunction

`undef DEBUG

