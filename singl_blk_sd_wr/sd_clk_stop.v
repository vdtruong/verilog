`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:08:09 12/03/2012 
// Design Name: 
// Module Name:    sd_clk_stop // Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		3.2.2 SD Clock Stop Sequence
//							The flow chart for stopping the SD Clock is shown in 
//							Figure 3-4. The Host Driver shall not stop the SD
//							Clock when a SD transaction is occurring on the 
//							SD Bus -- namely, when either Command Inhibit (DAT)
//							or Command Inhibit (CMD) in the Present State register is 
//							set to 1.
//							(1) Set SD Clock Enable in the Clock Control register to 0. 
//							Then, the Host Controller stops supplying
//							the SD Clock.	
//							We will also turn off the Int. Clk Enb bit and the
//							SDCLK Freq. Select bits.  The sd_clk_sup.v module will turn
//							all these bits on.  This module essentially turns off all the
// 						bits of the clock control register (2Ch).
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sd_clk_stop(
   input 				clk,
   input 				reset,
   input 				stop_sd_clk_strb,
	
	// For the Host Controller memory map
	output	[11:0]	rd_reg_index,
	input 	[127:0]	rd_reg_input,
	output				wr_reg_strb,
	output	[11:0]	wr_reg_index,
	output 	[31:0]	wr_reg_output,
	output 	[2:0]		reg_attr,
	
	// tells if we will sucessfully turn off the clock
	// because there is no longer any communication on the bus.
	// The host controller actually turns the sd clock off.
	output reg			sd_clk_off_suc,  	// strobe				 
	output reg			fin_stp_clk,  		// strobe
	output				sd_clk_stop_proc 	// tells that we're still in this module
   );
	 
	// Registers.
	reg 			wr_reg_strb_reg;
	reg [11:0] 	wr_reg_index_reg;
	reg [31:0]	wr_reg_output_reg;
	reg [11:0] 	rd_reg_index_reg;
	reg [2:0]	reg_attr_reg;
	reg			sd_clk_off_reg;
	reg			sd_clk_stop_proc_reg;    
	// need 3 clocks to get back reading from host controller
	reg			rd_reg_strb;
	
	// Initialize sequential logic
	initial			
	begin
		wr_reg_strb_reg		<= 1'b0;
		wr_reg_index_reg		<= 12'h000;
		wr_reg_output_reg		<= 32'h00000000;
		rd_reg_index_reg		<= 12'h000;
		reg_attr_reg			<= 3'h0;
		
		sd_clk_off_reg			<= 1'b0;
		sd_clk_off_suc			<= 1'b0;
		fin_stp_clk				<= 1'b0;
		sd_clk_stop_proc_reg	<= 1'b0;
		rd_reg_strb				<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign wr_reg_strb 		= wr_reg_strb_reg;
	assign wr_reg_index		= wr_reg_index_reg;
	assign wr_reg_output		= wr_reg_output_reg;
	assign rd_reg_index		= rd_reg_index_reg;
	assign reg_attr			= reg_attr_reg;
	//assign sd_clk_off			= sd_clk_off_reg;
	assign sd_clk_stop_proc	= sd_clk_stop_proc_reg;
	
	// Becareful, other registers are written to 
	// rd_reg_input.  rd_reg_index_reg tells you which register
	// you are reading from.  From 2.2.9 Present State Register (Offset 024h).
	// Check for Command Inhibit (DAT) and Command Inhibit (CMD).
	always@(posedge clk)
	begin
		if (reset) 
			sd_clk_off_reg	<= 1'b0;
		else 
			// The Host Driver shall not stop the SD
			// Clock when a SD transaction is occurring on the 
			//	SD Bus -- namely, when either Command Inhibit (DAT)
			//	or Command Inhibit (CMD) in the Present State register is 
			//	set to 1.  If either one of them is one, we do not
			// stop the sd clock.
			// Active low.
			sd_clk_off_reg	<= rd_reg_input[1] | rd_reg_input[0];
	end
	
	// Determines if we've sucessfully turned off the sd clock.
	// If both of the Command Inhibit (DAT) and Command Inhibit (CMD)
	// bits are off, we can turn off the sd clock.  Therefore, we
	// can turn off the sd clock by writing a 1 to the SD Clock Enable bit
	// in the clock control register.  This strobe tells us that
	// the clock will be turned off, it doesn't say that the clock has
	// been turned off.	You may need to AND this strobe with the
	// read_clks_tout strobe.  This is so we know when
	// this strobe is valid.  sd_clk_off_reg is always reading the
	// rd_reg_input input, in the beginning, rd_reg_input could have
	// any kind of reading.	 Make sure you know this when other
	// modules depend on this output strobe.
	always@(posedge clk)
	begin
		if (reset) 
			sd_clk_off_suc	<= 1'b0; 					 
		// If command inhibit (DAT) and (CMD) are 0s,
		// we can turn off the sdclk.
		else if (!sd_clk_off_reg && read_clks_tout)
			sd_clk_off_suc	<= 1'b1; 					
		else if (sd_clk_off_reg && read_clks_tout)
			sd_clk_off_suc	<= 1'b0;
		else
			sd_clk_off_suc	<= 1'b0;		
	end									 

	//-------------------------------------------------------------------------
	// We need a 3 clocks counter.  It takes 1 clock to get a reading for the
	// memory map from the host controller.  However, we'll use 3 clocks
	// to give it some room.  We also use this counter if we have two writes in
	// the row so we can have sometime in between.
	//-------------------------------------------------------------------------
	defparam readClksCntr.dw 	= 2;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam readClksCntr.max	= 2'h3;	
	//-------------------------------------------------------------------------
	CounterSeq readClksCntr(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_reg_strb | wr_reg_strb_reg),   	 	
		.cntr(), 
		.strb(read_clks_tout) 
	);							 

	// State machine for sd clock stop.
   parameter state_start 						= 10'b00_0000_0001;
   parameter state_rd_pres_ste_reg			= 10'b00_0000_0010;
   parameter state_rd_wait						= 10'b00_0000_0100;
   parameter state_sd_clk_off_reg 			= 10'b00_0000_1000;
   parameter state_sd_clk_off_reg_wt 		= 10'b00_0001_0000; 
   parameter state_dis_int_clk 				= 10'b00_0010_0000;
   parameter state_dis_int_clk_wt 			= 10'b00_0100_0000;
   parameter state_clr_sdclk_freq_sel		= 10'b00_1000_0000;
   parameter state_clr_sdclk_freq_sel_wt	= 10'b01_0000_0000;
   parameter state_end 							= 10'b10_0000_0000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [9:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         //<outputs> <= <initial_values>;
			rd_reg_index_reg 				<= 12'h000;
			wr_reg_strb_reg				<= 1'b0;
			wr_reg_index_reg 				<= 12'h000;
			wr_reg_output_reg				<= {32{1'b0}};
			reg_attr_reg					<= 3'h0;	  
			fin_stp_clk						<= 1'b0;
			sd_clk_stop_proc_reg			<= 1'b0;
			rd_reg_strb						<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
            state_start : begin 				// 10'b00_0000_0001
               if (stop_sd_clk_strb)
                  state 				<= state_rd_pres_ste_reg;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;	  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b0;
					rd_reg_strb				<= 1'b0;
            end
            state_rd_pres_ste_reg : begin	// 10'b00_0000_0010
					state 					<= state_rd_wait;
               //<outputs> <= <values>;
					// 2.2.9 Present State Register (Offset 024h) (pg 44)
					rd_reg_index_reg 		<= 12'h024;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;		  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b1;
            end										
            state_rd_wait : begin 			//	10'b00_0000_0100 			 			
               if (read_clks_tout)
                  state 				<= state_sd_clk_off_reg;
					// wait until time is up
               else if (!read_clks_tout)
                  state 				<= state_rd_wait;
               else								 
                  state 				<= state_end;
               //<outputs> <= <values>;
					rd_reg_index_reg		<= 12'h024;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;	  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;	
					rd_reg_strb				<= 1'b0;
				end
            state_sd_clk_off_reg : begin	// 10'b00_0000_1000 
					state 					<= state_sd_clk_off_reg_wt;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					wr_reg_index_reg 		<= 12'h02C;
					// The Host Driver shall not stop the SD
					// Clock when a SD transaction is occurring on the 
					//	SD Bus -- namely, when either Command Inhibit (DAT)
					//	or Command Inhibit (CMD) in the Present State register is 
					//	set to 1.  If both bits are off, we'll write 0 to 
					// SD Clock Enable in the clock control register.  If either 
					// one is on, we'll write 1 to the SD Clock Enable and the 
					// sd clock remains on.  This also makes the sd_clock_off_suc
					// output false.	
					wr_reg_output_reg		<= {{29{1'b0}},~sd_clk_off_reg,1'b0,1'b0};
					reg_attr_reg			<= 3'h3;		  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end							
            state_sd_clk_off_reg_wt : begin	// 10'b00_0001_0000 		 	 	 			
               if (read_clks_tout)
                  state 				<= state_dis_int_clk;
					// wait until time is up
               else if (!read_clks_tout)
                  state 				<= state_sd_clk_off_reg_wt;
               else								 
                  state 				<= state_end;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					wr_reg_index_reg 		<= 12'h02C;									 
					wr_reg_output_reg		<= {{29{1'b0}},~sd_clk_off_reg,1'b0,1'b0};
					reg_attr_reg			<= 3'h3;		  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end				
            state_dis_int_clk : begin			// 10'b00_0010_0000 
					state 					<= state_dis_int_clk_wt;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					wr_reg_index_reg 		<= 12'h02C;										 
					// We will also clear the Int. Clk Enb bit.
					wr_reg_output_reg		<= {{31{1'b0}},1'b1};
					reg_attr_reg			<= 3'h3;		  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end							
            state_dis_int_clk_wt : begin		// 10'b00_0100_0000 		 	 	 			
               if (read_clks_tout)
                  state 				<= state_clr_sdclk_freq_sel;
					// wait until time is up
               else if (!read_clks_tout)
                  state 				<= state_dis_int_clk_wt;
               else								 
                  state 				<= state_end;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					wr_reg_index_reg 		<= 12'h02C;									  
					wr_reg_output_reg		<= {{31{1'b0}},1'b1};
					reg_attr_reg			<= 3'h3;	  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end						
            state_clr_sdclk_freq_sel : begin	// 10'b00_1000_0000 
					state 					<= state_clr_sdclk_freq_sel_wt;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					wr_reg_index_reg 		<= 12'h02C;
					// Clear the sdclk freq. select bits.
					wr_reg_output_reg		<= {{16{1'b0}},{1'b0},{1'b1},{14{1'b0}}};
					reg_attr_reg			<= 3'h3;	  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end							
            state_clr_sdclk_freq_sel_wt : begin	// 10'b01_0000_0000 		 	 	 			
               if (read_clks_tout)
                  state 				<= state_end;
					// wait until time is up
               else if (!read_clks_tout)
                  state 				<= state_clr_sdclk_freq_sel_wt;
               else								 
                  state 				<= state_end;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					wr_reg_index_reg 		<= 12'h02C;										 						 
					// Clear the sdclk freq. select bits.
					wr_reg_output_reg		<= {{16{1'b0}},{1'b0},{1'b1},{14{1'b0}}};
					reg_attr_reg			<= 3'h3;		  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end										
            state_end : begin							// 10'b10_0000_0000
					state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;	
					fin_stp_clk				<= 1'b1;
					sd_clk_stop_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end
            default: begin  // Fault Recovery
               state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;	  
					fin_stp_clk				<= 1'b0;
					sd_clk_stop_proc_reg	<= 1'b0;
					rd_reg_strb				<= 1'b0;
				end
         endcase
							

endmodule
