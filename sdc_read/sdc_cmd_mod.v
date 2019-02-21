`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 			Fresenius
// Engineer: 			VDT
// 
// Create Date:    	11:52:31 08/13/2012 
// Design Name: 
// Module Name:    	sdc_cmd_mod 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		This module is responsible for forming the command packet
//							and sends it out.  It also returns the response coming  
//							back from the sd card.  The response will be upload to the
//                   memory map register.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sdc_cmd_mod(
	input					sd_clk,
   input 				reset,
	input					r2_resp_enb,
	//input 				inserted_card_strb,
	input					new_cmd_set_strb, // ready to package the command
	//input		[5:0]		cmd_index,
	//input		[31:0]	cmd_arg,
	// 2.2.6 Command Register (Offset 00Eh) (pg 40)
	input		[15:0] 	command,
	// 2.2.4 Argument 1 Register (Offset 008h)
	input		[31:0] 	argument_1,	
	// Will need to have two separate lines for this.
	// Only when we go out to the very top at the 
	// PUCIO top module do we combine the two lines
	// into one line.
	input					cmd_in,
	output				cmd_out,
	output				new_response_packet_strb,
	output				new_response_2_packet_strb,
	output 	[47:0] 	response_packet,
	output 	[135:0] 	r2_packet,
	output	[6:0]		cmd_crc7_out,
	output	[6:0]		resp_crc7_out,
	output	[6:0]		resp2_crc7_out,
	output				r1_crc7_good_out,
	output				r2_crc7_good_out,
	output 				end_bit_det_strb, // last command bit detected (stop bit)
	output				cmd_indx_err			  
	);
	
	// Registers 			  
	reg				new_cmd_set_strb_z1;
	reg				new_cmd_set_strb_z2;
	reg 	[47:0] 	cmd_packet;
	//reg 	[5:0]		cmd_index;
	//reg	[31:0]	cmd_arg;
	//reg	[15:0]	rca;
	// This register contains the first 40 bits of the new command.
	// Right now only uses this reg. for crc7 calc. for new command.
	reg 	[39:0]	pre_new_cmd; 
	reg				shift_pre_new_cmd;
	reg				shift_new_resp;	
	//reg 				oe_sig;	
	reg				new_cmd_strb;
	reg 				new_resp_packet_strb_z1;
	reg				new_resp_packet_strb_z2;
	reg				new_resp_packet_strb_z3;
	//reg				volt_accepted;
	//reg				good_chk_pattern;
	reg				resp_crc7_good;
	reg 	[47:0] 	resp_packet_reg;
	//reg				app_cmd_bit;
	//reg				valid_R7;
	//reg				valid_R7_z1;
	/*reg				new_state_strb;
	reg				new_state_strb_z1;
	reg				new_state_strb_z2;*/
	//reg				pass_cmd55_state;
	//reg				acmd41_busy_bit;
	//reg				acmd41_ccs;
	//reg				resend_acmd41_cmd;
	//reg	[15:0]	cid_oid; // from command cmd2
	//reg				r2_resp_enb;
	reg 	[135:0] 	r2_resp_packet_reg;
	reg				r2_crc7_good;
	reg				cmd_indx_err_reg;
	
	// Wires
	wire	[11:0]	cmd_crc7_cnt;
	wire	[6:0]		cmd_crc7;
	wire 				new_resp_packet_strb;
	wire				new_r2_packet_strb;
	wire 	[47:0] 	resp_packet;
	wire 	[135:0] 	resp2_packet;
	wire	[6:0]		resp_crc7;
	wire	[6:0]		resp2_crc7;
	wire				finish_40Clks_cmd_strb;
	wire				finish_40Clks_resp_strb;
	wire				finish_128Clks_resp_strb;
	wire				finish_48Clks_strb;
	wire				fin_shift_pre_new_cmd;
	//wire				resp_timeout_strb;
	
	// Initialize sequential logic (regs)
	initial			
	begin																	 
		new_cmd_set_strb_z1		<=	1'b0;							 
		new_cmd_set_strb_z2		<=	1'b0;
		cmd_packet 					<= {1'b0, 1'b1, {45{1'b0}}, 1'b1};
		//cmd_index					<= 6'h00;
		//cmd_arg						<= 32'h00000000;
		//rca							<= 16'h0000;
		pre_new_cmd 				<= {1'b0, 1'b1, {38{1'b0}}};
		shift_pre_new_cmd			<=	1'b0;
		shift_new_resp				<=	1'b0;
		//oe_sig						<=	1'b0;		
		new_cmd_strb				<=	1'b0;
		new_resp_packet_strb_z1	<= 1'b0;
		new_resp_packet_strb_z2	<= 1'b0;
		new_resp_packet_strb_z3	<= 1'b0;
		//volt_accepted 				<= 1'b0;
		//good_chk_pattern			<= 1'b0;
		resp_crc7_good 			<= 1'b0;
		resp_packet_reg 			<= {{47{1'b0}}, 1'b1};
		//app_cmd_bit					<= 1'b0;
		//valid_R7						<= 1'b0;
		//valid_R7_z1					<= 1'b0;
		//new_state_strb				<= 1'b0;
		//new_state_strb_z1			<= 1'b0;
		//new_state_strb_z2			<= 1'b0;
//		r2_resp_enb					<= 1'b1;
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
	
	// We need to build the cmd_packet.
	always@(posedge sd_clk)
	begin
		if (reset) begin
			cmd_packet	<= {1'b0, 1'b1, {45{1'b0}}, 1'b1};
		end
		else if (fin_shift_pre_new_cmd) begin // wait to get cmd_crc7
			cmd_packet	<= {1'b0, 1'b1, command[13:8], argument_1, cmd_crc7, 
								1'b1};
		end
	end
	
	// Create a flag to allow shifting of the pre_new_cmd for crc7 
	// calculation.  
	always@(posedge sd_clk)
	begin
		if (reset) begin
			shift_pre_new_cmd <= 1'b0; 		
		end
		else if (/*inserted_card_strb |	new_state_strb_z2 |*/
					new_cmd_set_strb_z2) begin
			shift_pre_new_cmd <= 1'b1;
		end
		// Also need to turn this off so we don't
		// have to shift it any more.
		else if (fin_shift_pre_new_cmd) begin
			shift_pre_new_cmd <= 1'b0;
		end
	end	
	
	// Shifts (left) the data into the crc7 calculator
	// and determines the next pre_new_cmd.
	always@(posedge sd_clk)
	begin
		if (reset) begin
			pre_new_cmd 		<= {1'b0, 1'b1, {38{1'b0}}}; 		
		end
		else if (shift_pre_new_cmd) begin			
			pre_new_cmd[39:1]	<= pre_new_cmd[38:0];
		end
		else if (new_cmd_set_strb)begin			
			// Set the pre_new_cmd according to command and argument_1.
			pre_new_cmd			<= {1'b0, 1'b1, command[13:8], argument_1};
		end
		else begin
			pre_new_cmd 		<= pre_new_cmd;
		end
	end	  
	
	// Create a flag to allow shifting of new response for crc7 calculation.
	always@(posedge sd_clk)
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
	always@(posedge sd_clk)
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
	always@(posedge sd_clk)
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
	
	// Calculates the crc7 of the pre_new_cmd.
	// When we shift the pre new command, we also
	// need to restart the crc calculator.
	sd_crc_7 genericCmdCrc7(
		.BITVAL(pre_new_cmd[39]),	// Next input bit
    	.Enable(shift_pre_new_cmd),      
		.CLK(sd_clk),    				// Current bit valid (Clock)
      .RST(/*inserted_card_strb  | new_state_strb_z2 |*/ new_cmd_set_strb),
   	.CRC(cmd_crc7)
	);
	
	// Need to calculate the crc7 of the response packet.
	// We calculate the crc7 everytime a response is received.
	sd_crc_7 genericRespCrc7(
		.BITVAL(resp_packet_reg[47]),	// Next input bit
    	.Enable(shift_new_resp),
      .CLK(sd_clk),    					// Current bit valid (Clock)
      .RST(new_resp_packet_strb_z3),// Init CRC value
   	.CRC(resp_crc7)
	);
	
	// Need to calculate the crc7 of the R2 response packet.
	// We calculate the crc7 everytime a response is received.
	sd_crc_7 genericR2RespCrc7(
		.BITVAL(r2_resp_packet_reg[135]),				// Next input bit
    	.Enable(shift_new_resp), // becareful, may need a separate flag
      .CLK(sd_clk),    										// Current bit valid (Clock)
      .RST(new_r2_packet_strb /*&& r2_resp_enb*/),// Init CRC value
   	.CRC(resp2_crc7)
	);
	
	//-------------------------------------------------------------------------
	// We need a generic 40 clocks counter for the command crc7 calculator.  
	//-------------------------------------------------------------------------
	defparam generic40ClksCmdCntr.dw 	= 8;
	defparam generic40ClksCmdCntr.max	= 8'h27;	// 40 counts (0-39).
	//-------------------------------------------------------------------------
	CounterSeq generic40ClksCmdCntr(
		.clk(sd_clk), 	// Clock input 400 kHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc7
		.start_strb(/*inserted_card_strb | new_state_strb_z2 |*/ new_cmd_set_strb_z2),  	 	
		.cntr(), 
		.strb(fin_shift_pre_new_cmd) // should finish calculating crc7.
	);
	
	//-------------------------------------------------------------------------
	// We need a generic 40 clocks counter for the response crc7 calculator.
	// We calculate the crc7 everytime a response is received.
	//-------------------------------------------------------------------------
	defparam generic40ClksRespCntr.dw 	= 8;
	defparam generic40ClksRespCntr.max	= 8'h27;	// 40 counts (0-39).
	//-------------------------------------------------------------------------
	CounterSeq generic40ClksRespCntr(
		.clk(sd_clk), 	// Clock input 400 kHz 
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
		.clk(sd_clk), 	// Clock input 400 kHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc7 when we have the response.
		.start_strb(new_r2_packet_strb /*&& r2_resp_enb*/),  	 	
		.cntr(), 
		.strb(finish_128Clks_resp_strb) // should finish calculating crc7.
	);
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// This is a generic 48 clocks counter.
	// Everytime we start to send a signal, we need to start the oe_sig and
	// this generic counter.
	//---------------------------------------------------------------
	defparam generic48ClksCmdCntr.dw 	= 8;
	defparam generic48ClksCmdCntr.max	= 8'h2f;	// 48 counts, starts at zero.
	//---------------------------------------------------------------
	CounterSeq generic48ClksCmdCntr (
		.clk(sd_clk), 					// Clock input 400 kHz 
		.reset(reset),					// GSR
		.enable(1'b1), 	
		// start to send a command
		.start_strb(finish_40Clks_cmd_strb /*| resend_acmd41_cmd*/),  	 	
		.cntr(), 
		.strb(finish_48Clks_strb) 	// should finish sending a command.      
	);
	
	//-------------------------------------------------------------------------
	// Generic response wait counter.
	// We need to give one second for the cmd to give a response. 
	// This is not in the specification but this is how we will try to validate
	// a response from a cmd.  We don't know when the response will come back
	// or it will at all.
	//-------------------------------------------------------------------------
//	defparam genericRespTimeoutCntr.dw 	= 12;
//	defparam genericRespTimeoutCntr.max	= 12'h4B0;	// 20'hC3500 800,000 counts.
//	//-------------------------------------------------------------------------
//	CounterSeq genericRespTimeoutCntr(
//		.clk(sd_clk), 							// Clock input 400 kHz 
//		// cancel it if we have sucessfully moved to the next state
//		.reset(reset | /*new_state_strb*/new_cmd_set_strb),	// GSR
//		.enable(1'b1), 			
//		// start to wait for a response.
//		.start_strb(/*new_state_strb_z2*/new_cmd_set_strb),  	 	
//		.cntr(cmd_crc7_cnt), 
//		.strb(resp_timeout_strb)			// timeout waiting for a response.            
//	);
	
	// Need to create a signal for the oe_reg.
	// Don't want to strobe it, need to carry it out
	// as long as we send the command.
	always @(posedge sd_clk)
		if(reset) begin
         //oe_sig 			<= 1'b0;	// output enable signal
			new_cmd_strb	<=	1'b0;
		end
		else if (fin_shift_pre_new_cmd) begin
			/* Send out the command after we have calclated the cmd crc7*/
			// Sends out data on the cmd line when oe_sig is one.
			// oe_sig is a latch, new_cmd_strb is a strobe.
         //oe_sig 			<= 1'b1;
			new_cmd_strb	<=	1'b1;
      end 
		else if (finish_48Clks_strb) begin
			/* We also need to turn it off oe_sig
			   when we are done with cmd0. */
			//oe_sig 			<= 1'b0;
		end
		else begin
			// create a strobe by pulling it to zero after one clock
			new_cmd_strb	<=	1'b0;
		end
	
	// Create an end_bit_det_strb when we are finished sending a command.
	/*always@(posedge sd_clk)
	begin
		if (reset) begin
			end_bit_det_strb <= 1'b0; 		
		end
		else if (finish_48Clks_strb) begin
			end_bit_det_strb <= 1'b1;
		end
		else begin
			end_bit_det_strb <= 1'b0;
		end
	end*/
	
	cmd_serial_mod cmd_serial_mod_u1(
		.sd_clk(sd_clk),
		.reset(reset),
		.r2_resp_enb(r2_resp_enb),
		//.oe_sig(),
		.snd_cmd_strb(snd_cmd_strb),
		.cmd_packet(cmd_packet),
		.cmd_in(cmd_in),			
		.cmd_out(cmd_out),						
		.end_bit_det_strb(end_bit_det_strb), 
		.new_resp_packet_strb(new_resp_packet_strb), 
		.new_r2_packet_strb(new_r2_packet_strb),
		.resp_packet(resp_packet),
		.resp2_packet(resp2_packet)
   );		
	
	/////////////////////////////////////////////////////
	// Set up delays.
	always@(posedge sd_clk)
	begin
		if (reset) begin						  
			new_cmd_set_strb_z1		<= 1'b0;	
			new_cmd_set_strb_z2		<= 1'b0;
			new_resp_packet_strb_z1	<= 1'b0;
			new_resp_packet_strb_z2	<= 1'b0;
			new_resp_packet_strb_z3	<= 1'b0;
			//valid_R7_z1					<= 1'b0;
			//new_state_strb_z1			<= 1'b0;
			//new_state_strb_z2			<= 1'b0;
			//resp_crc7_good_z1			<= 1'b0;
		end
		else begin								  
			new_cmd_set_strb_z1		<= new_cmd_set_strb;
			new_cmd_set_strb_z2		<= new_cmd_set_strb_z1;
			new_resp_packet_strb_z1	<= new_resp_packet_strb;
			new_resp_packet_strb_z2	<= new_resp_packet_strb_z1;
			new_resp_packet_strb_z3	<= new_resp_packet_strb_z2;
			//valid_R7_z1					<= valid_R7;
			//new_state_strb_z1			<= new_state_strb;
			//new_state_strb_z2			<= new_state_strb_z1;
			//resp_crc7_good_z1			<= resp_crc7_good;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////
	// Check the calculated response crc7 against the received response crc7
	////////////////////////////////////////////////////////////////////////////
	always @(posedge sd_clk)
	begin
		if(reset)
         resp_crc7_good		<= 1'b0;
		else if (finish_40Clks_resp_strb) begin
			// Compare the calculated resp. crc7 vs. the received resp. crc7
         if (resp_packet[7:1] == resp_crc7)
				resp_crc7_good <= 1'b1;
			else
				resp_crc7_good	<= 1'b0;
      end
		else
			resp_crc7_good		<= 1'b0;	 
	end
	////////////////////////////////////////////////////////////////////////////
	// Check the calculated R2 crc7 against the received R2 crc7.
	////////////////////////////////////////////////////////////////////////////
	always @(posedge sd_clk)
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
	always @(posedge sd_clk)
		if(reset) begin
         cmd_indx_err_reg		<= 1'b0;
      end
		else if (new_resp_packet_strb) begin
			// Compare the command index from the "command" input and 
			// the command index from the received response.
         if (resp_packet[45:40] != cmd_packet[45:40]) begin
				cmd_indx_err_reg 	<= 1'b1;
			end
			else begin
				cmd_indx_err_reg	<= 1'b0;
			end
      end
		else begin
			cmd_indx_err_reg		<= 1'b0;
		end
		
endmodule
