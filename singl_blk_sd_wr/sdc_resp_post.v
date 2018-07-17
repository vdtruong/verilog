`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 			Fresenius
// Engineer: 			VDT
// 
// Create Date:    	11:52:31 08/13/2012 
// Design Name: 
// Module Name:    	sdc_resp_post 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		This module is responsibled for sending out the command.    
//							It also returns the response coming back from the sd card.  
//                   The response will be upload to the memory map register.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sdc_resp_post(
	input					clk,
   input 				reset,
	input					r2_resp_enb,
	input					new_resp_packet_strb,
	input					new_r2_packet_strb,
	input 	[47:0] 	resp_packet,
	input 	[135:0] 	resp2_packet,
	output	[6:0]		cmd_crc7_out,
	output	[6:0]		resp_crc7_out,
	output	[6:0]		resp2_crc7_out,
	output				r1_crc7_good_out,
	output				r2_crc7_good_out,														
	output				cmd_indx_err			  
	);
	
	// Registers 			  	  	 		
	reg				shift_new_resp;
	reg 				new_resp_packet_strb_z1;
	reg				new_resp_packet_strb_z2;
	reg				new_resp_packet_strb_z3;
	reg				resp_crc7_good;
	reg 	[47:0] 	resp_packet_reg;				 
	reg 	[135:0] 	r2_resp_packet_reg;
	reg				r2_crc7_good;
	reg				cmd_indx_err_reg;
	
	// Wires
	wire	[11:0]	cmd_crc7_cnt;
	wire	[6:0]		cmd_crc7;
	//wire 				new_resp_packet_strb;
	//wire				new_r2_packet_strb;
	//wire 	[47:0] 	resp_packet;
	//wire 	[135:0] 	resp2_packet;
	wire	[6:0]		resp_crc7;
	wire	[6:0]		resp2_crc7;				  
	wire				finish_40Clks_resp_strb;
	wire				finish_128Clks_resp_strb;
	//wire				finish_48Clks_strb;	  
	
	// Initialize sequential logic (regs)
	initial			
	begin												
		shift_new_resp				<=	1'b0;
		new_resp_packet_strb_z1	<= 1'b0;
		new_resp_packet_strb_z2	<= 1'b0;
		new_resp_packet_strb_z3	<= 1'b0;	  
		resp_crc7_good 			<= 1'b0;
		resp_packet_reg 			<= {{47{1'b0}}, 1'b1};
		r2_resp_packet_reg		<= {{2{1'b0}}, {6{1'b1}}, {127{1'b0}}, 1'b1};
		r2_crc7_good				<= 1'b0;
		cmd_indx_err_reg			<= 1'b0;
	end  
	
	assign new_response_packet_strb 		= new_resp_packet_strb;
	assign new_response_2_packet_strb 	= new_r2_packet_strb;
	assign response_packet					= resp_packet;
	assign r2_packet							= resp2_packet;
	assign cmd_crc7_out 						= cmd_crc7;
	assign resp_crc7_out 					= resp_crc7;
	assign resp2_crc7_out 					= resp2_crc7;
	assign r1_crc7_good_out					= resp_crc7_good;
	assign r2_crc7_good_out					= r2_crc7_good;		 
	assign cmd_indx_err						= cmd_indx_err_reg;
	
	// Create a flag to allow shifting of new response for crc7 calculation.
	always@(posedge clk)
	begin
		if (reset) begin
			shift_new_resp <= 1'b0; 		
		end
		else if (new_resp_packet_strb_z3 | new_r2_packet_strb) begin
			// We automatically calculate the crc7 when we receive a response.
			shift_new_resp <= 1'b1;
		end
		// Also need to turn this off so we don't
		// have to shift it any more.
		else if (finish_40Clks_resp_strb | finish_128Clks_resp_strb) begin
			shift_new_resp <= 1'b0;
		end
	end
	
	// Shifts (left) the data into the generic response crc7 calculator
	// Also, sets the resp_packet_reg <= resp_packet.
	always@(posedge clk)
	begin
		if (reset) begin
			resp_packet_reg 				<= {{47{1'b0}}, 1'b1};
			//r2_resp_packet_reg			<= {{2{1'b0}}, {6{1'b1}}, {127{1'b0}}, 1'b1};
		end
		else if (shift_new_resp) begin			
			resp_packet_reg[47:1]		<= resp_packet_reg[46:0];
			//r2_resp_packet_reg[135:1] 	<= r2_resp_packet_reg[134:0];
		end
		else if (/*new_resp_packet_strb*/new_resp_packet_strb_z1) begin			
			resp_packet_reg 				<= resp_packet;
			//r2_resp_packet_reg			<= resp2_packet;
		end
	end
	
	// Shifts (left) the data into the generic response crc7 calculator
	// Also, sets the r2_resp_packet_reg <= resp_packet.
	always@(posedge clk)
	begin
		if (reset) begin
			//resp_packet_reg 				<= {{47{1'b0}}, 1'b1};
			r2_resp_packet_reg			<= {{2{1'b0}}, {6{1'b1}}, {127{1'b0}}, 1'b1};
		end
		else if (shift_new_resp) begin			
			//resp_packet_reg[47:1]		<= resp_packet_reg[46:0];
			r2_resp_packet_reg[135:1] 	<= r2_resp_packet_reg[134:0];
		end
		else if (new_r2_packet_strb) begin			
			//resp_packet_reg 				<= resp_packet;
			r2_resp_packet_reg			<= resp2_packet;
		end
	end										  
	
	// Need to calculate the crc7 of the response packet.
	// We calculate the crc7 everytime a response is received.
	sd_crc_7 genericRespCrc7(
		.BITVAL(resp_packet_reg[47]),	// Next input bit
    	.Enable(shift_new_resp),
      .CLK(clk),    					// Current bit valid (Clock)
      .RST(new_resp_packet_strb_z3),// Init CRC value
   	.CRC(resp_crc7)
	);
	
	// Need to calculate the crc7 of the R2 response packet.
	// We calculate the crc7 everytime a response is received.
	sd_crc_7 genericR2RespCrc7(
		.BITVAL(r2_resp_packet_reg[135]),				// Next input bit
    	.Enable(shift_new_resp), // becareful, may need a separate flag
      .CLK(clk),    										// Current bit valid (Clock)
      .RST(new_r2_packet_strb /*&& r2_resp_enb*/),// Init CRC value
   	.CRC(resp2_crc7)
	);																		 
	
	//-------------------------------------------------------------------------
	// We need a generic 40 clocks counter for the response crc7 calculator.
	// We calculate the crc7 everytime a response is received.
	//-------------------------------------------------------------------------
	defparam generic40ClksRespCntr.dw 	= 8;
	defparam generic40ClksRespCntr.max	= 8'h27;	// 40 counts (0-39).
	//-------------------------------------------------------------------------
	CounterSeq generic40ClksRespCntr(
		.clk(clk), 	// Clock input 400 kHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc7 when we have the response.
		.start_strb(new_resp_packet_strb_z3),  	 	
		.cntr(), 
		.strb(finish_40Clks_resp_strb) // should finish calculating crc7.
	);
	
	//-------------------------------------------------------------------------
	// We need a generic 128 clocks counter for response R2 crc7 calculator.
	// We calculate the crc7 everytime a response is received.
	//-------------------------------------------------------------------------
	defparam generic128ClksRespCntr.dw 	= 8;
	defparam generic128ClksRespCntr.max	= 8'h7f;	// 128 counts (0-127).
	//---------------------------------------------------------------
	CounterSeq generic128ClksRespCntr(
		.clk(clk), 	// Clock input 400 kHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc7 when we have the response.
		.start_strb(new_r2_packet_strb /*&& r2_resp_enb*/),  	 	
		.cntr(), 
		.strb(finish_128Clks_resp_strb) // should finish calculating crc7.
	);		
	
	/////////////////////////////////////////////////////
	// Set up delays.
	always@(posedge clk)
	begin
		if (reset) begin						  
			new_resp_packet_strb_z1	<= 1'b0;
			new_resp_packet_strb_z2	<= 1'b0;
			new_resp_packet_strb_z3	<= 1'b0;	  
		end
		else begin								  					  
			new_resp_packet_strb_z1	<= new_resp_packet_strb;
			new_resp_packet_strb_z2	<= new_resp_packet_strb_z1;
			new_resp_packet_strb_z3	<= new_resp_packet_strb_z2;	 
		end
	end
	
	////////////////////////////////////////////////////////////////////////////
	// Check the calculated response crc7 against the received response crc7
	////////////////////////////////////////////////////////////////////////////
	always @(posedge clk)
		if(reset) begin
         resp_crc7_good		<= 1'b0;
      end
		else if (finish_40Clks_resp_strb) begin
			// Compare the calculated resp. crc7 vs. the received resp. crc7
         if (resp_packet[7:1] == resp_crc7) begin
				resp_crc7_good <= 1'b1;
			end
			else begin
				resp_crc7_good	<= 1'b0;
			end
      end
		else begin
			resp_crc7_good		<= 1'b0;
		end
		
	////////////////////////////////////////////////////////////////////////////
	// Check the calculated R2 crc7 against the received R2 crc7.
	////////////////////////////////////////////////////////////////////////////
	always @(posedge clk)
		if(reset) begin
         r2_crc7_good		<= 1'b0;
      end
		else if (finish_128Clks_resp_strb) begin
			// Compare the calculated resp. crc7 vs. the received resp. crc7
         if (resp2_packet[7:1] == resp2_crc7) begin
				r2_crc7_good 	<= 1'b1;
			end
			else begin
				r2_crc7_good	<= 1'b0;
			end
      end
		else begin
			r2_crc7_good		<= 1'b0;
		end
		
	////////////////////////////////////////////////////////////////////////////
	// Check the command index coming back from the response.
	// This should apply only to R1, R6 and R7.
	////////////////////////////////////////////////////////////////////////////
	//always @(posedge clk)
//		if(reset) begin
//         cmd_indx_err_reg		<= 1'b0;
//      end
//		else if (new_resp_packet_strb) begin
//			// Compare the command index from the "command" input and 
//			// the command index from the received response.
//         if (resp_packet[45:40] != cmd_packet[45:40]) begin
//				cmd_indx_err_reg 	<= 1'b1;
//			end
//			else begin
//				cmd_indx_err_reg	<= 1'b0;
//			end
//      end
//		else begin
//			cmd_indx_err_reg		<= 1'b0;
//		end
		
endmodule
