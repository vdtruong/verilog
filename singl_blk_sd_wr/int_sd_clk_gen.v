`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:04:04 07/12/2013 
// Design Name: 
// Module Name:    int_sd_clk_gen 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:		This module generates the internal sd clk based on the
// 						Clock Control register.  It does not
//                   start the main clock on the sdc_clk line until the host
//							controller commands it to.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module int_sd_clk_gen(
    input 			clk,
    input 			reset,
    input 			int_clk_enb, 		// To keep generating the sd clock.
	 input [7:0] 	sdclk_freq_sel,
    output 			sd_clk_stable,
    output 			sdc_clk
    );

	// Local parameters.
	localparam sd_clk_mult = 20'hF4240; // sd clock multiplier is 1 MHz.
	 
	// Registers
	reg 			clk_already_on;
	reg 			sd_clk_stable_reg;
	reg [8:0] 	div; // sd clock divider
	reg 			sdc_clk_reg;
   reg 			int_clk_enb_strb; // To start the sd clock.
	// this flip from 1 to 0 and back to 1 to create the sd clock.
	reg 			flip_sig_strb; 

	// Wires
	wire			sig_196kHz_strb;
	wire			sig_390kHz_strb;
	wire			sig_781kHz_strb;
	wire			sig_1_56MHz_strb;
	wire			sig_3_125MHz_strb;
	wire			sig_6_25MHz_strb;
	wire			sig_12_5MHz_strb;
	wire			sig_25MHz_strb;
	
	// Initialize sequential logic
	initial			
	begin
		clk_already_on		<= 1'b0;
		sd_clk_stable_reg	<= 1'b0;
		int_clk_enb_strb	<= 1'b0;
		sdc_clk_reg			<= 1'b0;
		flip_sig_strb		<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign sd_clk_stable = sd_clk_stable_reg;
	assign sdc_clk			= sdc_clk_reg;
	
	
	// State machine to generate internal sd clk.
   parameter ste_start				= 5'b00001;
   parameter ste_gen_clk	 		= 5'b00010;
   parameter ste_stabl_wt			= 5'b00100;
   parameter ste_set_clk_stb_flg = 5'b01000;
   parameter ste_stp_clk 			= 5'b10000;
//   parameter <state6> = 5'b00100000;
//   parameter <state7> = 5'b01000000;
//   parameter <state8> = 5'b10000000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="ste_start" *) 
	reg [4:0] state = ste_start;

   always@(posedge clk)
      if (reset) begin
         state 						<= ste_start;
         //<outputs> <= <initial_values>;
			sd_clk_stable_reg			<= 1'b0;
			int_clk_enb_strb			<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
            ste_start : begin		  			// 5'b00001
               if (int_clk_enb && !clk_already_on)
                  state 			<= ste_gen_clk;
//               else if (int_clk_enb && clk_already_on)
//                  state <= ste_start;
//               if (!int_clk_enb && !clk_already_on)
//                  state <= ste_start;
               else if (!int_clk_enb && clk_already_on)
                  state 			<= ste_stp_clk;
               else
                  state 			<= ste_start;
               //<outputs> <= <values>;
					sd_clk_stable_reg	<= sd_clk_stable_reg;
					int_clk_enb_strb	<= 1'b0;
            end
            ste_gen_clk : begin	  			// 5'b00010
					state 				<= ste_stabl_wt;
               //<outputs> <= <values>;
					sd_clk_stable_reg	<= 1'b0;
					int_clk_enb_strb	<= 1'b1;
            end
            ste_stabl_wt : begin	  			// 5'b00100
               if (flip_sig_strb) // may need to wait longer
                  state 			<= ste_set_clk_stb_flg;
               else
                  state 			<= ste_stabl_wt;
               //<outputs> <= <values>;
					sd_clk_stable_reg	<= 1'b0;
					int_clk_enb_strb	<= 1'b0;
            end
            ste_set_clk_stb_flg : begin	// 5'b01000
					state 				<= ste_start;
               //<outputs> <= <values>;
					sd_clk_stable_reg	<= 1'b1;
					int_clk_enb_strb	<= 1'b0;
            end
            ste_stp_clk : begin				// 5'b10000
					state 				<= ste_start;
               //<outputs> <= <values>;
					// We don't need to do anything here since the
					// int_clk_enb flag already stopped the counter.
					sd_clk_stable_reg	<= 1'b0;
					int_clk_enb_strb	<= 1'b0;
            end
            default: begin  // Fault Recovery
               state 				<= ste_start;
               //<outputs> <= <values>;
					sd_clk_stable_reg	<= sd_clk_stable_reg;
					int_clk_enb_strb	<= 1'b0;
	    end
	endcase
	
	////////////////////////////////////////////////////
	// Set up the sd clock by using a counter.
	
	// We need to generate a divider based on the
	// sdclk_freq_sel from the Clock Control register.
	//always @(posedge clk) begin
//		if (reset) begin
//			div <= 256;
//		end
//		if (sdclk_freq_sel == 8'h01) begin
//			div <= 2;
//		end
//		else if (sdclk_freq_sel == 8'h02) begin
//			div <= 4;
//		end
//		else if (sdclk_freq_sel <= 8'h04) begin
//			div <= 8;
//		end
//		else if (sdclk_freq_sel <= 8'h08) begin
//			div <= 16;
//		end
//		else if (sdclk_freq_sel <= 8'h10) begin
//			div <= 32;
//		end
//		else if (sdclk_freq_sel <= 8'h20) begin
//			div <= 64;
//		end
//		else if (sdclk_freq_sel <= 8'h40) begin
//			div <= 128;
//		end
//		else if (sdclk_freq_sel <= 8'h80) begin
//			div <= 256;
//		end
//		else begin
//			div <= 256;
//		end 
//	end													
	
	// We need to generate a divider based on the
	// sdclk_freq_sel from the Clock Control register.
	always @(sdclk_freq_sel) begin
		case(sdclk_freq_sel)
			8'h01		:	div = 2; 		
			8'h02		:	div = 4; 	
			8'h04		:	div = 8; 	
			8'h08		: 	div = 16; 
			8'h10		:	div = 32; 	
			8'h20		:	div = 64; 	
			8'h40		: 	div = 128; 	
			8'h80		:	div = 256;	
			default	: 	div = 256;
		endcase
	end

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 196 kHz.
	// The div = 256 is for the entire period, not half of it.
	// Therefore, we need to count half of this for every
	// half period.
	//-------------------------------------------------------------------------
	defparam sdClk196kHz.dw 	= 8;
	// Change this to reflect the number of counts you want.
	defparam sdClk196kHz.max	= 8'h7E;	//0-126, period is 256	
	//-------------------------------------------------------------------------
	CounterSeq sdClk196kHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 256) | sig_196kHz_strb),   	 	
		.cntr(), 
		.strb(sig_196kHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 390 kHz.
	//-------------------------------------------------------------------------
	defparam sdClk390kHz.dw 	= 8;
	// Change this to reflect the number of counts you want.
	defparam sdClk390kHz.max	= 8'h3E;		// 0-62, period is 128	
	//-------------------------------------------------------------------------
	CounterSeq sdClk390kHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 128) | sig_390kHz_strb),   	 	
		.cntr(), 
		.strb(sig_390kHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 781 kHz.
	//-------------------------------------------------------------------------
	defparam sdClk781kHz.dw 	= 8;
	// Change this to reflect the number of counts you want.
	defparam sdClk781kHz.max	= 8'h1E;	
	//-------------------------------------------------------------------------
	CounterSeq sdClk781kHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 64) | sig_781kHz_strb),   	 	
		.cntr(), 
		.strb(sig_781kHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 1.56 MHz.
	//-------------------------------------------------------------------------
	defparam sdClk1_56MHz.dw 	= 4;
	// Change this to reflect the number of counts you want.
	defparam sdClk1_56MHz.max	= 4'hE;	
	//-------------------------------------------------------------------------
	CounterSeq sdClk1_56MHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 32) | sig_1_56MHz_strb),   	 	
		.cntr(), 
		.strb(sig_1_56MHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 3.125 MHz.
	//-------------------------------------------------------------------------
	defparam sdClk3_125MHz.dw 	= 4;
	// Change this to reflect the number of counts you want.
	defparam sdClk3_125MHz.max	= 4'h6;	
	//-------------------------------------------------------------------------
	CounterSeq sdClk3_125MHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 16) | sig_3_125MHz_strb),   	 	
		.cntr(), 
		.strb(sig_3_125MHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 6.25 MHz.
	//-------------------------------------------------------------------------
	defparam sdClk6_25MHz.dw 	= 4;
	// Change this to reflect the number of counts you want.
	defparam sdClk6_25MHz.max	= 4'h2;	
	//-------------------------------------------------------------------------
	CounterSeq sdClk6_25MHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 8) | sig_6_25MHz_strb),   	 	
		.cntr(), 
		.strb(sig_6_25MHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 12.5 MHz.
	//-------------------------------------------------------------------------
	defparam sdClk12_5MHz.dw 	= 4;
	// Change this to reflect the number of counts you want.
	defparam sdClk12_5MHz.max	= 4'h0;	
	//-------------------------------------------------------------------------
	CounterSeq sdClk12_5MHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 4) | sig_12_5MHz_strb),   	 	
		.cntr(), 
		.strb(sig_12_5MHz_strb) 
	);

	//-------------------------------------------------------------------------
	// This is for generating the internal sd clk 25 MHz.
	//-------------------------------------------------------------------------
	defparam sdClk25MHz.dw 	= 2;
	// Change this to reflect the number of counts you want.
	defparam sdClk25MHz.max	= 2'h0;	
	//-------------------------------------------------------------------------
	CounterSeq sdClk25MHz(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(int_clk_enb), 	
		// start the counting
		.start_strb((int_clk_enb_strb && div == 2) | sig_25MHz_strb),   	 	
		.cntr(), 
		.strb(sig_25MHz_strb) 
	);
	
	// Pick which counter to use depending on div.
	//always @(posedge clk) begin
//		if (reset) begin
//			flip_sig_strb <= sig_196kHz_strb;
//		end
//		if (div == 2) begin
//			flip_sig_strb <= sig_25MHz_strb; 
//		end
//		if (div == 4) begin
//			flip_sig_strb <= sig_12_5MHz_strb; 
//		end
//		if (div == 8) begin
//			flip_sig_strb <= sig_6_25MHz_strb; 
//		end
//		if (div == 16) begin
//			flip_sig_strb <= sig_3_125MHz_strb; 
//		end
//		if (div == 32) begin
//			flip_sig_strb <= sig_1_56MHz_strb; 
//		end
//		if (div == 64) begin
//			flip_sig_strb <= sig_781kHz_strb; 
//		end
//		if (div == 128) begin
//			flip_sig_strb <= sig_390kHz_strb; 
//		end
//		if (div == 256) begin
//			flip_sig_strb <= sig_196kHz_strb; 
//		end
//		else begin
//			flip_sig_strb <= sig_196kHz_strb;
//		end
//	end		 
	
// Pick which counter to use depending on div.	
// Start off with sequential, if possible use combinational.
	always @(div, sig_25MHz_strb, sig_12_5MHz_strb, sig_6_25MHz_strb, 
				sig_3_125MHz_strb, sig_1_56MHz_strb, sig_781kHz_strb,
				sig_390kHz_strb, sig_196kHz_strb) begin
		case(div)
			2			:	flip_sig_strb = sig_25MHz_strb; 		
			4			:	flip_sig_strb = sig_12_5MHz_strb; 	
			8			:	flip_sig_strb = sig_6_25MHz_strb; 	
			16			: 	flip_sig_strb = sig_3_125MHz_strb; 
			32			:	flip_sig_strb = sig_1_56MHz_strb; 	
			64			:	flip_sig_strb = sig_781kHz_strb; 	
			128		: 	flip_sig_strb = sig_390kHz_strb; 	
			256		:	flip_sig_strb = sig_196kHz_strb;	
			default	: 	flip_sig_strb = sig_196kHz_strb;
		endcase
	end
	
	// We generate the sd clock here base on which counter
	// is chosen.  Wonder what happens if we use combinational.
	// Will the signal level starts at 257 or 0?  Right now
	// it starts at 0.
	always @(posedge clk) begin
		if (reset) 
			sdc_clk_reg <= 0;
		// When the counter finishes, switch to level 1
		// if the last level was 0.  This is how we generate
		// a clock.
		if (flip_sig_strb && (sdc_clk_reg == 0)) 
			sdc_clk_reg <= 1; 
		// When the counter finishes, switch to level 0
		// if the last level was 1.
		else if (flip_sig_strb && (sdc_clk_reg == 1)) 
			sdc_clk_reg <= 0;
		else if (!int_clk_enb) 
			sdc_clk_reg <= 0; // make sure the clock stops at 0.
		else 
			// keep as is while waiting for the next strobe
			sdc_clk_reg <= sdc_clk_reg; 
	end
	
	// Keep track of clk_already_on.
	//always @(posedge clk) begin
//		if (reset) begin
//			clk_already_on <= 0;
//		end
//		else if (sd_clk_stable_reg	== 1'b1) begin
//			clk_already_on <= 1;
//		end
//		else begin
//			clk_already_on <= clk_already_on;
//		end
//	end		 
	
	// Keep track of clk_already_on.
	always @(reset, sd_clk_stable_reg) begin
		if (reset) 
			clk_already_on = 1'b0;
		else if (sd_clk_stable_reg	== 1'b1) 
			clk_already_on = 1'b1;					
		else 
			clk_already_on = 1'b0;
	end
	
							
endmodule
