/*
jumpers positions:

jmp1=open
jmp2=open - mode_none

jmp1=gnd
jmp2=open - mode_4mb

jmp1=open
jmp2=gnd  - mode_8mb

jmp1=gnd
jmp2=gnd  - mode_slow

jmp1=jmp2 - mode_slow4mb
*/

module jumpers(	nreset,
				clock,
				jmp1,
				jmp2,
				mode_8mb,
				mode_4mb,
				mode_slow,
				mode_slow4mb
				);

	parameter clock_div_stages = 7;


	input nreset;
	
	input clock;
	
	inout jmp1,jmp2;
	reg   jmp1,jmp2;
	
	output mode_8mb,mode_4mb,mode_slow,mode_slow4mb;
	reg    mode_8mb,mode_4mb,mode_slow,mode_slow4mb;


	reg i_8mb,i_4mb,i_slow,i_slow4mb;


	reg nrst_1,nrst_2,nrst_3;


	reg [clock_div_stages-1:0] dividers;
	reg div_sync;
	reg set_pulse,read_pulse;
	reg read_mode;


	reg both_open;


	// generate jumpers read sequence
	always @(posedge clock)
	begin
		dividers <= dividers+2'd1;

		div_sync <= dividers[clock_div_stages-1];
		
		if( (div_sync==1'b0) && (dividers[clock_div_stages-1]==1'b1) )
			set_pulse <= 1'b1;
		else
			set_pulse <= 1'b0;
		
		if( (div_sync==1'b1) && (dividers[clock_div_stages-1]==1'b0) )
			read_pulse <= 1'b1;
		else
			read_pulse <= 1'b0;

		if( read_pulse == 1'b1 )
		begin
			read_mode <= ~read_mode;
			// when read_mode = 1 - see if jmp1=jmp2
			// when read_mode = 0 - see if jmp1 or jmp2 shorted to gnd or open
		end
	end	



	// manipulate jumper pins
	always @(posedge clock)
	begin
		if( read_mode==1'b1 && set_pulse==1'b1 ) //prepare to detect jmp1=jmp2
		begin
			jmp1 <= 1'b0; // jmp1 emits 0
			jmp2 <= 1'bZ; // jmp2 will read smth
		end		

		if( read_mode==1'b0 && set_pulse==1'b1 ) // prepare to detect gnd shorting
		begin
			jmp1 <= 1'bZ;
			jmp2 <= 1'bZ;
		end
	end


	//read jumper pins state
	always @(posedge clock)
	begin

		if( read_pulse==1'b1 )
		begin

			// read jmp1=jmp2 state
			if( read_mode==1'b1 )
			begin
				i_slow4mb = 1'b0;

				if( both_open==1'b1 )
				begin

					if( jmp2==1'b0 )
						i_slow4mb = 1'b1;
				end	
			end

			// read jmp1 or jmp2 shorted to gnd
			if( read_mode==1'b0 )
			begin
				both_open = 1'b0;

				i_8mb  = 1'b0;
				i_4mb  = 1'b0;
				i_slow = 1'b0;

				case({jmp2,jmp1})

					2'b00: i_slow = 1'b1;

					2'b01: i_8mb  = 1'b1;

					2'b10: i_4mb  = 1'b1;

					2'b11: both_open = 1'b1;

				endcase
			end

		end
	end

	


	// sync nreset in
	always @(posedge clock)
	begin
		nrst_1 <= nreset;
		nrst_2 <= nrst_1;
		nrst_3 <= nrst_2;
	end



	// set output on reset end
	always @(posedge clock)
	begin
		if( nrst_2==1'b1 && nrst_3==1'b0 )
		begin
			mode_8mb     <= i_8mb;
			mode_4mb     <= i_4mb;
			mode_slow    <= i_slow;
			mode_slow4mb <= i_slow4mb;
		end
	end



endmodule
