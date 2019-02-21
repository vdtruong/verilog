`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 			Fresenius
// Engineer: 			VDT
// 
// Create Date:    	11:52:31 08/13/2012 
// Design Name: 
// Module Name:    	sdc_cmnd_pre 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		This module is responsibled for forming the command packet.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sdc_cmnd_pre(
	input						clk,
   input 					reset,					
	input						new_cmd_set_strb, // ready to package the command	
	// 2.2.6 Command Register (Offset 00Eh) (pg 40)
	input			[15:0]	command,
	// 2.2.4 Argument 1 Register (Offset 008h)
	input			[31:0] 	argument_1,			
	output reg				new_cmd_strb,	
	output reg 	[47:0]	cmd_packet,
	output		[6:0]		cmd_crc7_out		  	  
	);
	
	// Registers 			  
	reg				new_cmd_set_strb_z1;
	reg				new_cmd_set_strb_z2;
	// This register contains the first 40 bits of the new command.
	// Right now only uses this reg. for crc7 calc. for new command.
	reg 	[39:0]	pre_new_cmd; 
	reg				shift_pre_new_cmd;
	reg				fin_shift_pre_new_cmd_z1;
	reg				fin_shift_pre_new_cmd_z2;
	reg				fin_shift_pre_new_cmd_z3;
	
	// Wires
	wire	[11:0]	cmd_crc7_cnt;
	wire	[6:0]		cmd_crc7;	 
	wire				finish_40Clks_cmd_strb;
	wire				fin_shift_pre_new_cmd; 
	
	// Initialize sequential logic (regs)
	initial			
	begin																	 
		new_cmd_set_strb_z1			<=	1'b0;							 
		new_cmd_set_strb_z2			<=	1'b0;
		cmd_packet 						<= {1'b0, 1'b1, {45{1'b0}}, 1'b1};
		pre_new_cmd 					<= {1'b0, 1'b1, {38{1'b0}}};
		shift_pre_new_cmd				<=	1'b0;		
		new_cmd_strb					<=	1'b0;		
		fin_shift_pre_new_cmd_z1	<=	1'b0;		
		fin_shift_pre_new_cmd_z2	<=	1'b0;		
		fin_shift_pre_new_cmd_z3	<=	1'b0;	
	end  		
	
	assign cmd_crc7_out 			= cmd_crc7;		
	
	// Set up delays.
	always@(posedge clk)
	begin
		if (reset) begin						  
			new_cmd_set_strb_z1			<= 1'b0;	
			new_cmd_set_strb_z2			<= 1'b0;		
			fin_shift_pre_new_cmd_z1	<=	1'b0;		
			fin_shift_pre_new_cmd_z2	<=	1'b0;		
			fin_shift_pre_new_cmd_z3	<=	1'b0;				  
		end
		else begin								  
			new_cmd_set_strb_z1			<= new_cmd_set_strb;
			new_cmd_set_strb_z2			<= new_cmd_set_strb_z1;
			fin_shift_pre_new_cmd_z1	<=	fin_shift_pre_new_cmd;		
			fin_shift_pre_new_cmd_z2	<=	fin_shift_pre_new_cmd_z1;	
			fin_shift_pre_new_cmd_z3	<=	fin_shift_pre_new_cmd_z2;	
		end
	end				 
	
	// We need to build the cmd_packet.
	always@(posedge clk)
	begin
		if (reset) 
			cmd_packet	<= {1'b0, 1'b1, {45{1'b0}}, 1'b1};
//		else if (fin_shift_pre_new_cmd_z2)  // wait to get cmd_crc7
//			cmd_packet	<= {1'b0, 1'b1, command[13:8], {32{1'b0}}, {7{1'b0}}, 
//								1'b1};
		else if (fin_shift_pre_new_cmd_z1)  // wait to get cmd_crc7
			cmd_packet	<= {1'b0, 1'b1, command[13:8], argument_1, cmd_crc7, 
								1'b1};
		else 
			cmd_packet	<= cmd_packet;
	end
	
	// Create a flag to allow shifting of the pre_new_cmd for crc7 
	// calculation.  
	always@(posedge clk)
	begin
		if (reset)
			shift_pre_new_cmd <= 1'b0; 
		else if (new_cmd_set_strb_z2) 
			shift_pre_new_cmd <= 1'b1;
		// Also need to turn this off so we don't
		// have to shift it any more.
		else if (fin_shift_pre_new_cmd) 
			shift_pre_new_cmd <= 1'b0;
		else  
			shift_pre_new_cmd <= shift_pre_new_cmd;
	end	
	
	// Shifts (left) the data into the crc7 calculator
	// and determines the next pre_new_cmd.
	always@(posedge clk)
	begin
		if (reset) 
			pre_new_cmd 		<= {1'b0, 1'b1, {38{1'b0}}};
		else if (shift_pre_new_cmd)
			pre_new_cmd[39:1]	<= pre_new_cmd[38:0];
		else if (new_cmd_set_strb_z1)
			// Set the pre_new_cmd according to command and argument_1.
			pre_new_cmd			<= {1'b0, 1'b1, command[13:8], argument_1};
		else
			pre_new_cmd 		<= pre_new_cmd;
	end
	
	// Calculates the crc7 of the pre_new_cmd.
	// When we shift the pre new command, we also
	// need to restart the crc calculator.
	sd_crc_7 genericCmdCrc7(
		.BITVAL(pre_new_cmd[39]),	// Next input bit
    	.Enable(shift_pre_new_cmd),      
		.CLK(clk),    					// Current bit valid (Clock)
      .RST(new_cmd_set_strb),
   	.CRC(cmd_crc7)
	);	
	
	//-------------------------------------------------------------------------
	// We need a generic 40 clocks counter for the command crc7 calculator.  
	//-------------------------------------------------------------------------
	defparam generic40ClksCmdCntr.dw 	= 8;
	defparam generic40ClksCmdCntr.max	= 8'h26;	// 40 counts (0-39).
	//-------------------------------------------------------------------------
	CounterSeq generic40ClksCmdCntr(
		.clk(clk), 		// Clock input 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc7
		.start_strb(new_cmd_set_strb_z2),  	 	
		.cntr(), 
		.strb(fin_shift_pre_new_cmd) // should finish calculating crc7.
	);	
	
	// Strobe when the new command is ready.
	always @(posedge clk)
	begin
		if(reset) 												  
			new_cmd_strb	<=	1'b0;
		else if (fin_shift_pre_new_cmd_z3)
			new_cmd_strb	<=	1'b1;		 	
		else
			// create a strobe by pulling it to zero after one clock
			new_cmd_strb	<=	1'b0;
	end	 	 
		
endmodule
