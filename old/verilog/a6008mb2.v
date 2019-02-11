module a6008mb2( cpu_a,
				 cpu_d,
                 cpu_nas,cpu_nlds,cpu_nuds,cpu_clk,
				 cpu_nreset,
                 dram_nras,
                 dram_nlcas,dram_nucas,
				 dram_ma,
				 cfg1,cfg2
				 );

	input [23:1] cpu_a;

	inout [15:12] cpu_d;
	reg   [15:12] cpu_d;

	input cpu_nas,cpu_nlds,cpu_nuds; // cpu bus control signals
	input cpu_clk; // cpu clock

	input cpu_nreset; // cpu system reset

	output [0:3] dram_nras;
	reg    [0:3] dram_nras; // /RAS dram signals

	output dram_nlcas,dram_nucas;
	reg    dram_nlcas,dram_nucas; // /CAS dram signals

	output [9:0] dram_ma;
	reg    [9:0] dram_ma; // DRAM MAx addresses

	inout cfg1,cfg2; // config jumpers



	reg    mux_switch; // address MUXing

	reg  [3:0] datout; // data out

	wire [7:0] high_addr;
	wire [5:0] low_addr;

	reg which_ras[0:3]; // which /RAS signal to activate (based on a21-a23)
	reg mem_selected; // memory selected

	reg rfsh_ras,rfsh_cas; // refresh /RAS, /CAS generators (POSITIVE assertion)

	reg access_ras,access_cas; // normal access /RAS, /CAS generators (POSITIVE assertion)

	reg read_cycle; // if current cycle is read cycle
	reg write_cycle;
	reg autoconf_on;
	reg	cpu_nas_z; // 1 cycle later

	reg [1:0] rfsh_select; // for cycling refresh over every of four chips

	wire mode_8mb,mode_4mb,mode_slow,mode_slow4mb; // modes of operation




	// config jumpers reading
	jumpers jmp(.nreset(cpu_nreset),
				.clock(cpu_clk),
				.jmp1(cfg1),
				.jmp2(cfg2),
				.mode_8mb(mode_8mb),
				.mode_4mb(mode_4mb),
				.mode_slow(mode_slow),
				.mode_slow4mb(mode_slow4mb) );




	assign high_addr = cpu_a[23:16];
	assign low_addr  = cpu_a[6:1];

	// chip selector decoder
	always @*
	begin

		{which_ras[0],which_ras[1],which_ras[2],which_ras[3]} = 4'b0000; // default decoder state
		mem_selected = 1'b0;


		casex( high_addr )

		8'b001xxxxx: // $200000-$3fffff
		begin
			if( mode_8mb==1'b1 || mode_4mb==1'b1 || mode_slow4mb==1'b1 )
			begin
				which_ras[0] = 1'b1;
				mem_selected = 1'b1;
			end
		end

		8'b010xxxxx: // $400000-$5fffff
		begin
			if( mode_8mb==1'b1 || mode_4mb==1'b1 || mode_slow4mb==1'b1 )
			begin
				which_ras[1] = 1'b1;
				mem_selected = 1'b1;
			end
		end
		
		8'b011xxxxx: // $600000-$7fffff
		begin
			if( mode_8mb==1'b1 )
			begin
				which_ras[2] = 1'b1;
				mem_selected = 1'b1;
			end
		end
		
		8'b100xxxxx: // $800000-$9fffff
		begin
			if( mode_8mb==1'b1 )
			begin
				which_ras[3] = 1'b1;
				mem_selected = 1'b1;
			end
		end

		8'b110xxxxx:  // c00000-d7ffff - slow memory mapping
		begin
			if( (mode_slow==1'b1 || mode_slow4mb==1'b1) && ( high_addr[4:3]==2'b00 || high_addr[4:3]==2'b01 || high_addr[4:3]==2'b10 ) )
			begin
				which_ras[2] = 1'b1;
				mem_selected = 1'b1;
			end
		end
		
		default: begin end
		
		endcase
	end


	// normal cycle generator
	always @(posedge cpu_clk,posedge cpu_nas)
	begin
		if( cpu_nas==1 )
		begin // /AS=1
			access_ras <= 0;
			access_cas <= 0;
		end
		else
		begin // /AS=0, positive clock
			access_ras <= 1;
			access_cas <= access_ras; // one clock later
		end
	end




	// refresh cycle generator
	always @(negedge cpu_clk)
	begin
		if( cpu_nas==1 ) // /AS negated
		begin
			rfsh_cas <= ~rfsh_cas;
		end
		else // /AS asserted
		begin
			rfsh_cas <= 0;
		end

		if( (rfsh_cas == 1'b0) && (cpu_nas==1) )
		begin
			rfsh_select <= rfsh_select + 2'b01;
		end
	end

	always @*
	begin
		rfsh_ras <= rfsh_cas & cpu_clk;
	end



	// output signals generator
	always @*
	begin
		dram_nras[0] <= ~( ( which_ras[0] & access_ras ) | ((rfsh_select==2'b00)?rfsh_ras:1'b0) );
		dram_nras[1] <= ~( ( which_ras[1] & access_ras ) | ((rfsh_select==2'b01)?rfsh_ras:1'b0) );
		dram_nras[2] <= ~( ( which_ras[2] & access_ras ) | ((rfsh_select==2'b10)?rfsh_ras:1'b0) );
		dram_nras[3] <= ~( ( which_ras[3] & access_ras ) | ((rfsh_select==2'b11)?rfsh_ras:1'b0) );

		dram_nlcas <= ~( ( ~cpu_nlds & access_cas & mem_selected ) | rfsh_cas );
		dram_nucas <= ~( ( ~cpu_nuds & access_cas & mem_selected ) | rfsh_cas );
	end






	// MUX switcher generator
	always @(negedge cpu_clk,negedge access_ras)
	begin
		if( access_ras==0 )
		begin // reset on no access_ras
			mux_switch <= 0;
		end
		else
		begin // set to 1 on negedge after beginning of access_ras
			mux_switch <= 1;
		end
	end

	// DRAM MAx multiplexor
	always @*
	begin
		if( mux_switch==0 )
			dram_ma[9:0] <= cpu_a[20:11];
		else // mux_switch==1
			dram_ma[9:0] <= cpu_a[10:1];
	end





	// make clocked cpu_nas_z
	always @(posedge cpu_clk)
	begin
		cpu_nas_z <= cpu_nas;
	end

	// detect if current cycle is read or write cycle
	always @(posedge cpu_clk, posedge cpu_nas)
	begin
		if( cpu_nas==1 ) // async reset on end of /AS strobe
		begin
			read_cycle  <= 0; // end of cycles
			write_cycle <= 0;
		end
		else // sync beginning of cycle
		begin
			if( cpu_nas==0 && cpu_nas_z==1 ) // beginning of /AS strobe
			begin
				if( (cpu_nlds&cpu_nuds)==0 )
					read_cycle <= 1;
				else
					write_cycle <= 1;
			end
		end
	end

	// autoconfig data forming
	always @*
	begin
		case( low_addr )
		6'b000000: // $00
			datout <= 4'b1110;
		6'b000001: // $02
			begin
				if( mode_8mb==1'b1 )
					datout <= 4'b0000;
				else if( mode_4mb==1'b1 || mode_slow4mb==1'b1 )
					datout <= 4'b0111;
				else datout <= 4'bxxxx;
					//datout <= 4'b0000; // 0111 for 4mb, 0000 for 8mb
			end

		6'b000010: // $04
			datout <= 4'hE;
		6'b000011: // $06
			datout <= 4'hE;

		6'b000100: // $08
			datout <= 4'h3;
		6'b000101: // $0a
			datout <= 4'hf;

		6'b001000: // $10
			datout <= 4'hE;
		6'b001001: // $12
			datout <= 4'hE;

		6'b001010: // $14
			datout <= 4'he;
		6'b001011: // $16
			datout <= 4'he;

		6'b100000: // $40
			datout <= 4'b0000;
		6'b100001: // $42
			datout <= 4'b0000;

		default:
			datout <= 4'b1111;
		endcase
	end

	// out autoconfig data
	always @*
	begin
		if( read_cycle==1 && high_addr==8'hE8 && autoconf_on==1 && (mode_8mb==1'b1 || mode_4mb==1'b1 || mode_slow4mb==1'b1) )
			cpu_d[15:12] <= datout;
		else
			cpu_d[15:12] <= 4'bZZZZ;
	end

	// autoconfig cycle on/off
	always @(posedge write_cycle,negedge cpu_nreset)
	begin
		if( cpu_nreset==0 ) // reset - begin autoconf
			autoconf_on <= 1;
		else
		begin
			if( high_addr==8'hE8 && low_addr[5:2]==4'b1001 ) // $E80048..$E8004E
				autoconf_on <= 0;
		end
	end


endmodule
