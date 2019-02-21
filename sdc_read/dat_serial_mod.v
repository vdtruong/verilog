`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    	13:49:39 10/17/2012
// Update Date:    	 			03/21/2014 
// Design Name: 
// Module Name:    	dat_serial_mod 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:		This module is responsibled for physically sending out  
//							the serial data and listening to the data coming back.
//							Need to write code for receiving data later.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: For now, we'll code for 512 bytes for one block read.  
//
///////////////////////////////////////////////////////////////////////////////
module dat_serial_mod(
	input					sd_clk,
	input					reset,
   //input 				oe_sig,
	input					new_dat_strb,
   input 	[63:0]	dat_pkt,
   input 				dat_in, 
   output reg			dat_out,
	output				new_rd_pkt_strb, // new read pkt is available
   output 	[4113:0] rd_pkt
   );
	 
	// Registers 
	reg 		[4113:0] dat_pkt_reg;
	reg					oe_reg;	
	reg					dat_out_reg;
	reg					dat_in_z1;
	reg					rd_reg;				// holds the read bit coming back
	reg					rd_reg_z1;
	reg					rd_pkt_strt_strb; // read pkt has started
	reg 		[4113:0] rd_pkt_reg;
	reg					rd_pkt_done_reg;	  
	reg					new_rd_pkt_rdy_z1;
	reg					new_dat_strb_z1;	
	reg					new_dat_strb_z2;
	reg					new_dat_strb_z3;
	reg					new_dat_strb_z4;
	
	// Wires
	wire		[11:0]	rd_pkt_cnt;			// Counts how many bits in read data pkt
	wire					new_rd_pkt_rdy;	// new read data pkt is ready
	wire					fin_dat_out;		// finished sending out data.

	////////////////////////////////////////////////////////////////////////////
	
	////////////////////////////////////////////////////////////////////////////
	// Intialize regs.
	initial			
	begin
		dat_pkt_reg 		<= {4114{1'b1}};
		oe_reg				<= 1'b0;
		dat_out				<= 1'b1;
		dat_out_reg			<= 1'b1;
		dat_in_z1			<= 1'b1;
		rd_reg				<= 1'b1;
		rd_reg_z1			<= 1'b1;
		rd_pkt_strt_strb	<= 1'b0;
		rd_pkt_reg 			<= {4114{1'b1}};
		rd_pkt_done_reg	<= 1'b0;		  
		new_rd_pkt_rdy_z1	<= 1'b0;
		new_dat_strb_z1	<= 1'b0;
		new_dat_strb_z2	<= 1'b0;
		new_dat_strb_z3	<= 1'b0;
		new_dat_strb_z4	<= 1'b0;
	end		  
	
	// Set up delays.
	always@(posedge sd_clk)		
	begin
		if (reset) begin		  	  
         dat_in_z1 			<= 1'b1;	
			new_dat_strb_z1	<= 1'b0;	
			new_dat_strb_z2	<= 1'b0;	
			new_dat_strb_z3	<= 1'b0;	
			new_dat_strb_z4	<= 1'b0;		  
			new_rd_pkt_rdy_z1	<= 1'b0;
		end
		else begin																		
         dat_in_z1 			<= dat_in;		
			new_dat_strb_z1	<= new_dat_strb;
			new_dat_strb_z2	<= new_dat_strb_z1;
			new_dat_strb_z3	<= new_dat_strb_z2;
			new_dat_strb_z4	<= new_dat_strb_z3;		  
			new_rd_pkt_rdy_z1	<= new_rd_pkt_rdy;
		end
	end
	////////////////////////////////////////////////////////////////////////////
	
	////////////////////////////////////////////////////////////////////////////
	// Start of sending data.
	
	////////////////////////////////////////////////////////////////////////////
	// Send out datas using sd_clk when oe_reg is true.
	
	// Need to create a signal for the oe_reg.
	// Don't want to strobe it, need to carry it out
	// as long as we send the data.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         oe_reg 	<= 1'b0;	
		else if (new_dat_strb_z4) 
         oe_reg 	<= 1'b1;
		else if (fin_dat_out) 
			oe_reg 	<= 1'b0;
		else
			oe_reg	<=	oe_reg;						
	end 						
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// Need 4114 clocks to push out the dat_pkt on to the cmd_out line.
	//-------------------------------------------------------------------------
	defparam datOutCntr.dw 	= 13;
	defparam datOutCntr.max	= 13'h1013;	
	//-------------------------------------------------------------------------
	CounterSeq datOutCntr(
		.clk(sd_clk), 	// sd clock 
		.reset(reset),	
		.enable(1'b1), 	
		.start_strb(new_dat_strb_z4), 	 	
		.cntr(), 
		.strb(fin_dat_out)            
	);	 

	//Capture and Shift (left) the data, MSB first.
	always@(posedge sd_clk)
	begin
		if (reset) begin						  				 
			dat_pkt_reg 			<= {4114{1'b1}};
			dat_out_reg				<= 1'b1;
		end
		else if (new_dat_strb) begin
			// new packet when we get new_dat_strb
			dat_pkt_reg 			<= dat_pkt;	// new pkt
			dat_out_reg				<= 1'b1;	
		end
		else if (oe_reg) begin 							 
			// shift if output enable is on
			dat_pkt_reg[4113:1]	<= dat_pkt_reg[4112:0];							  
			dat_out_reg				<= dat_pkt_reg[4113];	// msbit first;
		end
//		else
//			cmd_pkt_reg 		<= cmd_pkt_reg;
	end		
										  
	// Output the data.
	always @(posedge sd_clk) 
	begin
      if (reset) 							
         dat_out	<= 1'b1;		
		else
			dat_out	<= dat_out_reg;
	end	 
	// End of sending data.
	////////////////////////////////////////////////////////////////////////////
	
	////////////////////////////////////////////////////////////////////////////
	// Start of listening to read data.  This is for reading data from sd card.
	assign rd_pkt 				= rd_pkt_reg; 		 	// new read data pkt
	assign new_rd_pkt_strb 	= new_rd_pkt_rdy_z1;
	
	// Create delay.
	always@(posedge sd_clk)
	begin
		if (reset)
			new_rd_pkt_rdy_z1	<= 1'b0; 				 
		else 
			new_rd_pkt_rdy_z1	<= new_rd_pkt_rdy;
	end
	
	// Create falling edge strobe to start counter.
	// This is to count the amount of clocks that passed
	// since we started to capture the read data.
	// We need to stop at 4096 clocks for read data.
	always@(posedge sd_clk)
	begin
		if (reset) 
			rd_pkt_strt_strb	<= 1'b0;
		// falling edge, not output enable and read data pkt count
		// must be zero.  Not in the middle of counting.
		else if ((!dat_in && dat_in_z1) && !oe_reg && (rd_pkt_cnt == 0)) 
			rd_pkt_strt_strb 	<= 1'b1;												 
		else 
			rd_pkt_strt_strb 	<= 1'b0;	
		// use this technique to create a strobe.
	end					  											
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// We'll create a strobe to start listening to the read data. 
	// This usually lasts for 4096 clocks for read data.
	//-------------------------------------------------------------------------
	defparam cntRdCntr_u1.dw 	= 13;
	// tweak, if we count too much, we'll end up shifting the 
	// read data pkt too much.
	defparam cntRdCntr_u1.max	= 13'h100E;	
	//-------------------------------------------------------------------------
	CounterSeq cntRdCntr_u1(
		.clk(sd_clk), 							 
		.reset(reset | new_rd_pkt_rdy),	// GSR and reset when done
		.enable(1'b1), 	
		.start_strb(rd_pkt_strt_strb), 	 	
		.cntr(rd_pkt_cnt), 
		.strb(new_rd_pkt_rdy)            
	);
	
	// Create a latch to stop shifting the rd_pkt_reg after we have finished
	// collecting the data.
	always@(posedge sd_clk)
	begin
		if (reset) 
			rd_pkt_done_reg	<= 1'b0;
		else if (new_rd_pkt_rdy) 
			rd_pkt_done_reg	<= 1'b1;
		else if (rd_pkt_strt_strb)
			rd_pkt_done_reg	<= 1'b0;
	end
	
	// Shift (left) the data in for read data.
	always@(posedge sd_clk)
	begin
		if (reset) 
			rd_pkt_reg 				<= {4114{1'b0}};
		// The first time we detect the read data, we need to initialize the 
		// read data register so we can do the shifting cleanly.
		// Fallen edge for rd_reg.
		else if ((!dat_in && dat_in_z1) && !oe_reg && (rd_pkt_cnt == 0))
			rd_pkt_reg 				<= {4114{1'b0}}; // reset rd pkt reg 
		// Shift if output enable is off,  
		// we are not done with the pkt (4114 counts).
		// Also, this is for any read data that has only
		// 4114 bits.
 		else if (!oe_reg && (!rd_pkt_done_reg)) begin
			rd_pkt_reg[0] 			<= dat_in;
			rd_pkt_reg[4113:1]	<= rd_pkt_reg[4112:0];	
		end
	end
	// End of reading data.
	////////////////////////////////////////////////////////////////////////////
	
endmodule
