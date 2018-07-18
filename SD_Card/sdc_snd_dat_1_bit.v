`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:          Fresenius NA
// Engineer:         V. Truong   
// 
// Create Date:      17:04:40 03/25/2014 
// Design Name: 
// Module Name:      sdc_snd_dat_1_bit 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision:         07/30/2016 Add oe_reg_z1 to raise the write busy flag.
// Revision 0.01 - File Created
// Additional Comments:	This module takes the system memory input and sends it out  
//							   to the sd card.  The CRC was already calculated when we
//								save the puc data to the fifo.  It is also saved to the 
//								fifo as the last item.
//
//////////////////////////////////////////////////////////////////////////////////
module sdc_snd_dat_1_bit(
   input 					sd_clk,
   input 					reset,															
	input						strt_snd_data_strb,	// start to fetch first set of data.
   output wire   			new_dat_strb,			// Ready for new data word.
	input			[63:0]	sm_rd_data,				// from the system memory RAM
   input 		[15:0] 	pkt_crc,  				// CRC of 512 bytes packet.
	output					dat_tf_done,			// Finished with data transfer for one block.
	output					wr_busy,					// sd card is busy with writing	
	input						D0_in,					// Data in from sd card.
   output reg 				dat_out
   );																 
	
	// Registers.																			
   reg 				strt_snd_data_strb_z1;	// delay								
   reg 				strt_snd_data_strb_z2;	// delay								
   reg 				strt_snd_data_strb_z3;	// delay								
   reg 				strt_snd_data_strb_z4;	// delay
	reg	[63:0] 	dat_pkt_reg;				// placeholder for sm_rd_data
	reg				oe_reg;	               // output enable     
	reg				oe_reg_z1;              // output enable delay
	reg				stp_strb_for_dat;		   // stop strobing for new data					  
	reg				nxt_dat_strb_z1;        // delay	                    					  
	reg				nxt_dat_strb_z2;        // delay	  					  
	reg				nxt_dat_strb_z3;        // delay	  					  
	reg				nxt_dat_strb_z4;        // delay	  
   reg 				D0_in_z1;				   // delay
	// dat0 line is busy flag, pull down by sd card
	reg				wr_busy_flg;		
   //reg            new_dat_strb;           // new data word strobe
   reg            look_for_D0_rise;       // start looking for D0 rise after sending to sdc
	
	// Wires.                                                                    
	wire				fin_calc_crc_strb;
	wire				fin_set_strb;			      // finish data set.					
	wire	[15:0]	bit_out_cntr;			      // Counts how many bits have gone out.
	wire				fin_dat_out;			      // finished sending out data.			  
	wire				fin_all_dat_strb;		      // finished all 64 sets of data.
   wire           nxt_dat_strb;              // ready for next word
   wire  [7:0]    dataWrdCnt;                // Count each word used.
   wire           strt_look_for_D0_rise_strb;// Start looking for D0 rise after the sd card has released the line.
   
   assign         new_dat_strb = nxt_dat_strb && oe_reg;
	
	////////////////////////////////////////////////////////////////////////////
	// Initialize regs.
	initial			
	begin
		dat_out						<= 1'b1;	
		D0_in_z1						<= 1'b1; 
		strt_snd_data_strb_z1	<= 1'b0;	 
		strt_snd_data_strb_z2	<= 1'b0;	 
		strt_snd_data_strb_z3	<= 1'b0;	 
		strt_snd_data_strb_z4	<= 1'b0;
		dat_pkt_reg 				<= {64{1'b1}};
		oe_reg						<= 1'b0;	     
		oe_reg_z1					<= 1'b0; 
		stp_strb_for_dat			<= 1'b0;
		wr_busy_flg					<= 1'b0;
		//new_dat_strb			   <= 1'b0;
	end
	
	// Assign output.
	assign	dat_tf_done = fin_dat_out;
   // busy is pulled down for 1 block of data,
   // which is 512 bytes of data.
	assign	wr_busy 		= wr_busy_flg; 
	
	// Create delays.
	always @(posedge sd_clk) 
	begin
		if(reset) begin 						 
			strt_snd_data_strb_z1	<= 1'b0;	 
			strt_snd_data_strb_z2	<= 1'b0;	 
			strt_snd_data_strb_z3	<= 1'b0;	 
			strt_snd_data_strb_z4	<= 1'b0;
			D0_in_z1						<= 1'b1;
         oe_reg_z1					<= 1'b0;
		end
		else begin 	 								  
			strt_snd_data_strb_z1	<= strt_snd_data_strb;
			strt_snd_data_strb_z2	<= strt_snd_data_strb_z1;
			strt_snd_data_strb_z3	<= strt_snd_data_strb_z2;
			strt_snd_data_strb_z4	<= strt_snd_data_strb_z3;
			D0_in_z1						<= D0_in;
         oe_reg_z1					<= oe_reg;
		end
	end 	  	
	
	////////////////////////////////////////////////////////////////////////////
	// Start of sending data.
	
	////////////////////////////////////////////////////////////////////////////
	// Send out data using sd_clk when oe_reg is true.
	
	// Need to create a signal for the oe_reg.
	// Don't want to strobe it, need to carry it out
	// as long as we send the data.  It will be turned on
   // for 512 bytes of data at a time.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         oe_reg 	<= 1'b0;	
		else if (strt_snd_data_strb_z2) 
         oe_reg 	<= 1'b1;
		else if (fin_dat_out) 
			oe_reg 	<= 1'b0;
		else
			oe_reg	<=	oe_reg;						
	end 								 	  						
	
	/////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// Need 4114 clocks to push out the dat_pkt (1 block) on to the dat_out line.
   // This is for one block of data, which is 512 bytes.  For the PUC, this is
   // 64 words of 64 bits each.
	//-------------------------------------------------------------------------
	defparam datOutCntr.dw 	= 16;
	defparam datOutCntr.max	= 16'h1011;	 // Need to tweak.
	//-------------------------------------------------------------------------
	CounterSeq datOutCntr(
		.clk(sd_clk), 	// sd clock 
		.reset(reset),	
		.enable(1'b1), 	
		.start_strb(strt_snd_data_strb_z2), 	 	
		.cntr(bit_out_cntr), 
		.strb(fin_dat_out)            
	);	 

	// Capture and Shift (left) the data, MSBit first.
	always@(posedge sd_clk)
	begin
		if (reset) begin						  				 
			dat_pkt_reg 			<= {64{1'b1}}; 
		end
		else if (strt_snd_data_strb_z2 || nxt_dat_strb)
			// new packet when we start the transfer and everytime
			// we strobe for the next data set.
         // For PUC, one set is one word of data.  One word is 64 bits.
			dat_pkt_reg 			<= sm_rd_data;					// new pkt  	
		else if (oe_reg) //begin 							 
			// shift and push if output enable is on
			dat_pkt_reg[63:1]		<= dat_pkt_reg[62:0];
		else 
			dat_pkt_reg				<= dat_pkt_reg;
	end							                                          
										  
	// Output the data.
	always @(posedge sd_clk) 
	begin
      if (reset) 							
         dat_out	<= 1'b1;	
      else if (strt_snd_data_strb_z2) 							
         dat_out	<= 1'b0;		// The start bit.                	
		else if (oe_reg)									
			dat_out	<= dat_pkt_reg[63];
		else	
			dat_out  <= 1'b1;
	end	 
	
	//-------------------------------------------------------------------------
	// We need to strobe for a new word of data every 62 clocks.
	// We need to strobe 2 clocks before the data word is finished.
   // For PUC, one word is 64 bits.
   // Basically, we need to strobe for the next word before we finsihed
   // sending out the present word.  We do this for 64 times, ie 64 words.
   // This counts every bit of each word.
	//-------------------------------------------------------------------------
	defparam newDatSetCntr.dw 	= 8;
	defparam newDatSetCntr.max	= 8'h3E;	// 62.
	//-------------------------------------------------------------------------
	CounterSeq newDatSetCntr(
		.clk(sd_clk), 	
		.reset(reset),			
		.enable(1'b1), 	
		// Strobe for new set of data until we have strobed 64 times.
		.start_strb((strt_snd_data_strb_z2 || nxt_dat_strb) && (!stp_strb_for_dat) /*&& (dataWrdCnt > 8'h00 )*/),  	 	
		.cntr(), 
		.strb(nxt_dat_strb) 	// Next data set.
	); 							                                          
										  
	// Strobe for next data word
   //
//	always @(posedge sd_clk) 
//	begin
//      if (reset) 							
//         new_dat_strb	<= 1'b0;	
//      else if (nxt_dat_strb && (dataWrdCnt < 8'h41)) 							
//         new_dat_strb	<= 1'b1;		
//		else		
//         new_dat_strb	<= 1'b0;
//	end		  
	
	//-------------------------------------------------------------------------
	// We need to count how many words of data already used.
	// If we have used 63 words, we need to stop.
	// The first word is already loaded when we first start to transfer.
   // For PUC, one word is 64 bits.
	//-------------------------------------------------------------------------
  	defparam finAllDatSetsCntr.dw 	= 8;
  	defparam finAllDatSetsCntr.max	= 8'h41;
  	//---------------------------------------------------------------
  	Counter finAllDatSetsCntr 
  	(
    	.clk(sd_clk),
    	.reset(reset),
    	.enable(strt_snd_data_strb_z2 || nxt_dat_strb),
    	.cntr(dataWrdCnt),
    	.strb(fin_all_dat_strb)
  	); 	  
	
	// Need to know when to stop strobing for new data set.
	always@(posedge sd_clk)
	begin
		if (reset) 
			stp_strb_for_dat <= 1'b0;
		else if (fin_all_dat_strb) 
			stp_strb_for_dat <= 1'b1;	
		else if (strt_snd_data_strb) 
			stp_strb_for_dat <= 1'b0;	// reset
		else 
			stp_strb_for_dat <= stp_strb_for_dat;
	end
	
	// We know DAT0 is busy if it is held low after 
	// a successful transfer of data to the sd card.
	// When the DAT0 line is released to high, the line
	// is no longer busy.  We only monitor this when oe_reg
	// is off.  This is for one block of data.  One block of
   // data is 512 bytes.  For the PUC, it is 64 words of 64
   // bits each.  It might be easier to raise this write busy
   // flag after oe_reg falls.  When D0_in rises during oe_reg
   // low, we can clear the write busy signal.  Becareful since
   // we are artificially raising the busy flag instead of 
   // waiting for the sdc to lower the D0_in line.  What if it doesn't
   // lower the D0_in signal?  Possibly keep track of the busy
   // line by using a timer and releasing it after awhile.
   // Base on the chipscope of D0_in, we should wait for 10
   // sd_clks or more before looking for the rise of D0_in.
	always@(posedge sd_clk)
	begin
		if (reset)
			wr_busy_flg	<= 1'b0;									  
		else if (!oe_reg && oe_reg_z1)                                 // falling edge
			wr_busy_flg	<= 1'b1;		
            // only search after 20 clocks when oe_reg falls
		else if (!oe_reg && (D0_in && !D0_in_z1) && look_for_D0_rise)  // rising edge
			wr_busy_flg	<= 1'b0;
	end 					 
	// End of sending data.
	////////////////////////////////////////////////////////////////////////////

   // Want to wait 20 clocks before starting to look for D0 rise.  This is
   // when the sd card releases the D0 line.
	//-------------------------------------------------------------------------
	defparam waitB4SearchForD0RiseCntr.dw 	= 5;
	defparam waitB4SearchForD0RiseCntr.max	= 5'h14;	// 20d.
	//-------------------------------------------------------------------------
	CounterSeq waitB4SearchForD0RiseCntr(
		.clk(sd_clk), 	
		.reset(reset),			
		.enable(1'b1), 	
		// Start when finished sending out one block of data.
		.start_strb(fin_dat_out),  	 	
		.cntr(), 
		.strb(strt_look_for_D0_rise_strb)      // Start looking for D0 rise.
	); 	
   
   // Want to wait 10 clocks before looking for a rise in D0_in.
   // This is when the card is no longer busy.
	always@(posedge sd_clk)
	begin
		if (reset)
			look_for_D0_rise	<= 1'b0;									  
		else if (strt_look_for_D0_rise_strb)   // start looking for D0 rise
			look_for_D0_rise	<= 1'b1;									  
		else if (strt_snd_data_strb)           // stop looking for D0 rise
			look_for_D0_rise	<= 1'b0;
	end 	

endmodule

	