`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:04:40 03/25/2014 
// Design Name: 
// Module Name:    sdc_snd_dat_4_bits 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments:	This module takes one byte of data and splits it into
// 							the four data lines.  It then sends it out.  It also
//								calculates the CRC as it sends out the data.  In the end
//								it will also sends the CRC out.
//
//////////////////////////////////////////////////////////////////////////////////
module sdc_snd_dat_4_bits(
    input 				sd_clk,
    input 				reset,
    input 				dat_byte_strb,		// Next data byte.
    input 				new_dat_set_strb,	// New data set of 1024 bits.
    input 		[7:0] dat,
    output reg 		dat0_out,
    output reg 		dat1_out,
    output reg 		dat2_out,
    output reg 		dat3_out
    );
	
	wire	[1:0]		crc_cnt;			// Counts twice to calculate crc.
	wire	[15:0]	dat0_crc16;		// CRC 16.
	wire	[15:0]	dat1_crc16;		// CRC 16.
	wire	[15:0]	dat2_crc16;		// CRC 16.
	wire	[15:0]	dat3_crc16;		// CRC 16.
	wire				fin_calc_crc_strb;
	wire				fin_set_strb;	// finish data set.
	
	////////////////////////////////////////////////////////////////////////////
	// Intialize regs.
	initial			
	begin
		dat0_out		<= 1'b0;
		dat1_out		<= 1'b0;
		dat2_out		<= 1'b0;
		dat3_out		<= 1'b0;
		crc 			<= {16{1'b0}};
	end	
	
	// Split up the data into four data lines.
	// We will send out one bit per count using the
	// crc counter.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         dat3_out 	<= 1'b0;	
		else if (crc_cnt == 1)
         dat3_out 	<= dat[7];
		else if (crc_cnt == 2)
         dat3_out 	<= dat[3];						
	end 	  
	
	// Split up the data into four data lines.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         dat2_out 	<= 1'b0;	
		else if (crc_cnt == 1)
         dat2_out 	<= dat[6];
		else if (crc_cnt == 2)
         dat2_out 	<= dat[2];						
	end 	  
	
	// Split up the data into four data lines.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         dat1_out 	<= 1'b0;	
		else if (crc_cnt == 1)
         dat1_out 	<= dat[5];
		else if (crc_cnt == 2)
         dat1_out 	<= dat[1];						
	end 	  
	
	// Split up the data into four data lines.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         dat0_out 	<= 1'b0;	
		else if (crc_cnt == 1)
         dat0_out 	<= dat[4];
		else if (crc_cnt == 2)
         dat0_out 	<= dat[0];						
	end 	  
	
	// Create a flag to allow shifting of the data for crc16 
	// calculation.  
	always@(posedge sd_clk)
	begin
		if (reset) 
			calc_crc <= 1'b0;
		else if (dat_byte_strb) 
			calc_crc <= 1'b1;	
		// Also need to turn this off so we don't
		// have to shift it any more.
		else if (fin_calc_crc_strb) 
			calc_crc <= 1'b0;
	end
	
	//-------------------------------------------------------------------------
	// This counter counts twice to calculate the CRC16 for each two bits
	// whenever the data byte input strobes.  
	//-------------------------------------------------------------------------
	defparam crcCntr.dw 	= 2;
	defparam crcCntr.max	= 2'h2;	// 2 counts (1-2).
	//-------------------------------------------------------------------------
	CounterSeq crcCntr(
		.clk(sd_clk), 	
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc16
		.start_strb(dat_byte_strb),  	 	
		.cntr(crc_cnt), 
		.strb(fin_calc_crc_strb) // should finish calculating crc16.
	);
	
	// Calculates the crc16 of dat3.
	sd_crc_16 calcCRC3(
		.BITVAL(dat3_out),		// Next input bit
		// Enable it for two clocks.  First clock is for dat[7],
		// second clock is for dat[3].
    	.Enable(calc_crc),      	
		.CLK(sd_clk),    			// Current bit valid (Clock)
      .RST(new_dat_set_strb),	// Reset for new data set.
   	.CRC(dat3_crc16)
	);  
	
	// Calculates the crc16 of dat2.
	sd_crc_16 calcCRC2(
		.BITVAL(dat2_out),		// Next input bit
		// Enable it for two clocks.  First clock is for dat[6],
		// second clock is for dat[2].
    	.Enable(calc_crc),      	
		.CLK(sd_clk),    			// Current bit valid (Clock)
      .RST(new_dat_set_strb),	// Reset for new data set.
   	.CRC(dat2_crc16)
	);  
	
	// Calculates the crc16 of dat1.
	sd_crc_16 calcCRC1(
		.BITVAL(dat1_out),		// Next input bit
		// Enable it for two clocks.  First clock is for dat[5],
		// second clock is for dat[1].
    	.Enable(calc_crc),      	
		.CLK(sd_clk),    			// Current bit valid (Clock)
      .RST(new_dat_set_strb),	// Reset for new data set.
   	.CRC(dat1_crc16)
	);  
	
	// Calculates the crc16 of dat0.
	sd_crc_16 calcCRC0(
		.BITVAL(dat0_out),		// Next input bit
		// Enable it for two clocks.  First clock is for dat[4],
		// second clock is for dat[0].
    	.Enable(calc_crc),      	
		.CLK(sd_clk),    			// Current bit valid (Clock)
      .RST(new_dat_set_strb),	// Reset for new data set.
   	.CRC(dat0_crc16)
	);  
	
	//-------------------------------------------------------------------------
	// This counter starts counting when we have a new set of data.
	// When it finishes, we are ready to send the crc to the sd card.
	//-------------------------------------------------------------------------
	defparam datByteCntr.dw 	= 12;
	defparam datByteCntr.max	= 12'h200;	// 512 counts (1-512).
	//-------------------------------------------------------------------------
	CounterSeq datByteCntr(
		.clk(sd_clk), 	
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the counter
		.start_strb(new_dat_set_strb),  	 	
		.cntr(), 
		.strb(fin_set_strb) // finish data set.
	);



endmodule

	