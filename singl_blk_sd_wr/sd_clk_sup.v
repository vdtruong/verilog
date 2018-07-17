`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:14:44 11/30/2012 
// Design Name: 
// Module Name:    sd_clk_sup 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 	3.2.1 SD Clock Supply Sequence (page 94)
//						The sequence for supplying SD Clock to a SD card is described 
//						in Figure 3-3. The clock shall be supplied
//						to the card before either of the following actions is taken.
//						a) Issuing a SD command
//						b) Detect an interrupt from a SD card in 4-bit mode.
//						(1) Calculate a divisor to determine SD Clock frequency by 
//							reading Base Clock Frequency For SD
//							Clock in the Capabilities register. If Base Clock  
//							Frequency for SD Clock is 00 0000b, the Host
//							System shall provide this information to the Host Driver 
//							by another method.  Right now we'll set BCF to be 31 MHz.
//						(2) Set Internal Clock Enable and SDCLK Frequency Select in 
//							the Clock Control register in
//							accordance with the calculated result of step (1).
//						(3) Check Internal Clock Stable in the Clock Control  
//							register.  Repeat this step until Clock Stable is 1.
//						(4) Set SD Clock Enable in the Clock Control register to 1. 
//							Then, the Host Controller starts to supply
//							the SD Clock. 
//						This module sets up the parameters for the sd clock.
//						It doesn't necessary generate the clock.  A separate
// 					module in the host controller will do that.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sd_clk_sup(
   input 				clk,
   input 				reset,
	// Starts to calculate the clock divisor and ultimately the sd clock 
	// frequency.  Starts this module.
	input 				calc_clk_strb, 
   input 	[23:0] 	req_clk, 		// requested clock frequency
	input					dat_tf_mode,	// after initialization
	
	// For the Host Controller memory map
	output	[11:0]	rd_reg_index,
	input 	[127:0]	rd_reg_input,
	output				wr_reg_strb,
	output	[11:0]	wr_reg_index,
	output 	[31:0]	wr_reg_output,
	output 	[2:0]		reg_attr,
	
	output 				sd_clk_enb_strb, 	// sd clock is ready to be used
	output				sd_clk_proc 		// indicates that we are in this module
   );

	// Local parameters.
	localparam sd_clk_mult = 24'h0F4240; // sd clock multiplier is 1 MHz.
	
	// Registers 		
	reg [7:0] 	bcf_for_sdclk; 	// Base Clock Frequency For SD Clock
	reg [27:0] 	bcf_div;				// Base Clock Frequency divisor
	reg [7:0] 	sdclk_freq_sel;	// SDCLK Frequency Select
	reg			int_clk_stable;	// Check for the Internal Clock Stable.
	reg 			wr_reg_strb_reg;
	reg [11:0] 	wr_reg_index_reg;
	reg [31:0]	wr_reg_output_reg;
	reg [11:0] 	rd_reg_index_reg;
	reg [2:0]	reg_attr_reg;
	reg			sd_clk_enb_strb_reg;
	reg			sd_clk_proc_reg;
	// need 1 clock to get back reading from host controller
	reg			rd_reg_strb; 
	
	// Wire
	wire			read_clks_tout;	// time to read data from host controller
	
	// Initialize sequential logic
	initial			
	begin
		bcf_for_sdclk			<= 8'h00;
		bcf_div					<= 28'h0000000;
		sdclk_freq_sel			<= 8'h40;
		int_clk_stable			<= 1'b0;
		wr_reg_strb_reg		<= 1'b0;
		wr_reg_index_reg		<= 12'h000;
		wr_reg_output_reg		<= 32'h00000000;
		rd_reg_index_reg		<= 12'h000;
		reg_attr_reg			<= 3'h0;
		sd_clk_enb_strb_reg	<= 1'b0;
		sd_clk_proc_reg		<= 1'b0;
		rd_reg_strb				<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign wr_reg_strb 		= wr_reg_strb_reg;
	assign wr_reg_index		= wr_reg_index_reg;
	assign wr_reg_output		= wr_reg_output_reg;
	assign rd_reg_index		= rd_reg_index_reg;
	assign reg_attr			= reg_attr_reg;
	assign sd_clk_proc		= sd_clk_proc_reg;
	assign sd_clk_enb_strb	= sd_clk_enb_strb_reg;
	
	// Becareful, other registers are written to 
	// rd_reg_input.  rd_reg_index_reg tells you which register
	// you are reading from.  From 2.2.25 Capabilities Register (Offset 040h).
	// Check for the Base Clock Frequency (System Clock) For SD Clock.
	always@(posedge clk)
	begin
		if (reset) begin
			bcf_for_sdclk	<= 8'h00; 		
		end
		else begin
			bcf_for_sdclk	<= rd_reg_input[15:8];
		end
	end
	
	// Calculate the Base Clock Frequency divisor based on the requested clock
	// and the Base Clock Frequency For SD Clock.
	// For now we will only use two different frequencies.
	// 390 kHz for initialization and 1.56 MHz for data transfer mode.
	always@(posedge clk)
	begin
		if (reset)
			bcf_div	<= 28'h0000000;
		else if (dat_tf_mode)// make sure the digits work out when we simulate
									// we may have different digits here.
			//bcf_div	<= (bcf_for_sdclk*sd_clk_mult) / req_clk;
			bcf_div	<= 28'h0000020; // after initialization, 1.56 MHz
		else
			bcf_div	<= 28'h0000080; // for initialiation, 390 kHz
	end
	
	// Set the SDCLK Frequency Select in the Clock Control Register. 
	// SDCLK Frequency Select	 														 
	/*	(1) 8-bit Divided Clock Mode
	This mode is supported by the Host Controller Version 1.00 and 2.00. The
	frequency is not programmed directly; rather this register holds the divisor 
	of the Base Clock Frequency For SD Clock in the Capabilities register. Only
	the following settings are allowed.  Our Base Clock Frequency for this system
	is 50 MHz.
	80h base clock divided by 256	(bcf_div, 256 is for one period, not half)
	40h base clock divided by 128
	20h base clock divided by 64
	10h base clock divided by 32
	08h base clock divided by 16
	04h base clock divided by 8
	02h base clock divided by 4
	01h base clock divided by 2
	00h Base clock (10MHz-63MHz)*/	
	// The frequency of SDCLK is set by the following formula:
	// Clock Frequency = (Base Clock) / divisor
	// For example, if we set BCF to be 50 MHz and our desired freq. is 
	// 400 kHz, then our bcf_div is 125.  This value is 7Dh, which
	// is below 80h.  Therefore, our clock freq is 50 MHz/128 = 390 kHz.
	// We get 128 with the 2.2.14 Clock Control Register (Offset 02Ch)
	// table.  We don't divide by 40h, but what 40h respresents, which
	// is 128.  We don't divide by sdclk_freq_sel but what it represents.
	// This will be done in the Host Controller module.
	always@(posedge clk)
	begin
		if (reset) 
			sdclk_freq_sel	<= 8'h40;
		else if (bcf_div <= 28'h0000002) 
			sdclk_freq_sel	<= 8'h01; 
		else if (bcf_div <= 28'h0000004) 
			sdclk_freq_sel	<= 8'h02; 
		else if (bcf_div <= 28'h0000008) 
			sdclk_freq_sel	<= 8'h04;	
		else if (bcf_div <= 28'h0000010) // 16, 1.56 MHz
			sdclk_freq_sel	<= 8'h08;	
		else if (bcf_div <= 28'h0000020) // 32
			sdclk_freq_sel	<= 8'h10;	
		else if (bcf_div <= 28'h0000040)	// 64
			sdclk_freq_sel	<= 8'h20; 
		else if (bcf_div <= 28'h0000080) // 128, 390 kHz
			sdclk_freq_sel	<= 8'h40; 
		else if (bcf_div <= 28'h0000100) // 256
			sdclk_freq_sel	<= 8'h80;
		// When we go back to the host controller,
		// we will actually use bcf_div to find the
		// sd clock frequency.  sdclk_freq_sel is just 
		// a symbol.
		// We need 400 kHz in the beginning
		// when we are initializing the card.
		else
			sdclk_freq_sel	<= 8'h40;
	end
	
	// Becareful, other registers are written to 
	// rd_reg_input.  rd_reg_index_reg tells you which register
	// you are reading from.  From 2.2.14 Clock Control Register (Offset 02Ch).
	// Check for the Internal Clock Stable.
	always@(posedge clk)
	begin
		if (reset) 
			int_clk_stable	<= 1'b0;
		else 
			int_clk_stable	<= rd_reg_input[1];
	end

	//-------------------------------------------------------------------------
	// We need a x clocks counter.  It takes 1 clock to get a reading for the
	// memory map from the host controller.  However, we'll use x clocks
	// to give it some room.
	//-------------------------------------------------------------------------
	defparam readClksCntr_u1.dw 	= 2;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam readClksCntr_u1.max	= 2'h2;	
	//-------------------------------------------------------------------------
	CounterSeq readClksCntr_u1(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_reg_strb),   	 	
		.cntr(), 
		.strb(read_clks_tout) 
	);
	
	// State Machine for sd clock supply.
   parameter state_start 					= 8'b0000_0001;
   parameter state_calc_div 				= 8'b0000_0010;
   parameter state_rd_wait 				= 8'b0000_0100;
   parameter state_set_sdclk 				= 8'b0000_1000;
   parameter state_chk_int_clk_stable 	= 8'b0001_0000; 
   parameter state_rd_wait2 				= 8'b0010_0000;
   parameter state_set_sdclk_on 			= 8'b0100_0000;
   parameter state_end 						= 8'b1000_0000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [7:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         //<outputs> <= <initial_values>;
			rd_reg_index_reg 				<= 12'h000;
			wr_reg_strb_reg				<= 1'b0;
			wr_reg_index_reg 				<= 12'h000;
			wr_reg_output_reg				<= {32{1'b0}};
			reg_attr_reg					<= 3'h0; // type of bit write
			rd_reg_strb						<= 1'b0;
			sd_clk_enb_strb_reg			<= 1'b0;
			sd_clk_proc_reg				<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
            state_start : begin					// 8'b0000 0001
               if (calc_clk_strb)
                  state 				<= state_calc_div;
               else if (!calc_clk_strb)
                  state 				<= state_start;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b0; 
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b0;
            end
            state_calc_div : begin				// 8'b0000 0010						 
              	state 					<= state_rd_wait;  
               //<outputs> <= <values>;
					// 2.2.25 Capabilities Register (Offset 040h)
					rd_reg_index_reg 		<= 12'h040; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b1;	// create strobe
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b1;
            end									 
            state_rd_wait : begin				// 8'b0000 0100
               if (!read_clks_tout) // if time is not up, wait here
                  state 				<= state_rd_wait;			  
               else if (read_clks_tout) 
                  state 				<= state_set_sdclk;
					else
						state 				<= state_rd_wait;
               //<outputs> <= <values>;
					// 2.2.25 Capabilities Register (Offset 040h)
					rd_reg_index_reg 		<= 12'h040; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b0;	
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b1;
            end
            state_set_sdclk : begin				// 8'b0000 1000
					state 					<= state_chk_int_clk_stable;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= 12'h02C;
					// When the Internal Clock Enable bit is set,
					// we need to tell the Host Controller to start
					// to oscillate the oscillator to the required frequency.
					// The Host Controller needs to start it.
					// Need to write code in the host controller to start
					// the clock oscillation.  Maybe set up different counters
					// for all the frequencies then turn on the right one
					// when needed.  After we enable the sd clock, we also need
					// to find out when it is stable.   
					wr_reg_output_reg		<= {{16{1'b0}},sdclk_freq_sel,// freq. selection
													 {7{1'b0}},1'b1};			   // enb. internal clk
					reg_attr_reg			<= 3'h0;	// type of bit write
					rd_reg_strb				<= 1'b0; 
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b1;
            end
            state_chk_int_clk_stable : begin	// 8'b0001 0000	
               state 					<= state_rd_wait2;
               //<outputs> <= <values>;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					// When the Host Controller detects the
					// oscillator is stable, it will set the
					// Internal Clock Stable bit.
					// Need to write code in the host controller
					// to detect stability.	 Find out how many
					// clock it takes to generate the oscillator output.
					// We need to know this for simulation.
					rd_reg_index_reg 		<= 12'h02C; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {{16{1'b0}},sdclk_freq_sel,
													 {7{1'b0}},1'b1};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b1;
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b1;
            end												 
            state_rd_wait2 : begin				// 8'b0010 0000
               if (int_clk_stable)
                  state 				<= state_set_sdclk_on;
					// May want to put a timeout here.
					// May get stuck here.
               else if (!int_clk_stable) // wait until stable
                  state 				<= state_rd_wait2;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					// When the Host Controller detects the
					// oscillator is stable, it will set the
					// Internal Clock Stable bit.
					// Need to write code in the host controller
					// to detect stability.	 Find out how many
					// clock it takes to generate the oscillator output.
					// We need to know this for simulation. 
					// The int_sd_clk_gen module will tell us when the
					// sd clock is stable.
					rd_reg_index_reg 		<= 12'h02C; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b0;
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b1;	
				end
            state_set_sdclk_on : begin			// 8'b0100 0000	
               state 					<= state_end;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= 12'h02C;
					// When the frequency is stable, then
					// we set the SD Clock Enable bit to 
					// turn on the sd clock.  This sd clock
					// will then be used to clock the sd card,
					// commands and data line(s).
					wr_reg_output_reg		<= {{16{1'b0}},{8{1'b0}},
													 {5{1'b0}},1'b1,1'b0,1'b0};
					reg_attr_reg			<= 3'h0;
					rd_reg_strb				<= 1'b0;
					sd_clk_enb_strb_reg	<= 1'b1;
					sd_clk_proc_reg		<= 1'b1;
            end
            state_end : begin						// 8'b1000 0000	
					state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b0;
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b0;
            end
            default: begin  // Fault Recovery
               state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					rd_reg_strb				<= 1'b0;
					sd_clk_enb_strb_reg	<= 1'b0;
					sd_clk_proc_reg		<= 1'b0;
				end
			endcase
			
endmodule
