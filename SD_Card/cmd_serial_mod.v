`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    	13:49:39 08/22/2012 	
// Update Date:					01/17/2014
// Design Name: 
// Module Name:    	cmd_serial_mod 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:		This module is responsibled for sending out the serial cmd 
//							and listening to the response coming back.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 		
//	01/17/2014:  Change cmd to two lines like i2c.
//
///////////////////////////////////////////////////////////////////////////////
module cmd_serial_mod(
	input					sd_clk,
	input					reset,
	input					r2_resp_enb,											
	input					snd_cmd_strb,
   input 	[47:0]	cmd_packet,
   input 				cmd_in, // data from response or from card (d0-d3)	  
   output reg			cmd_out,// data sent out to card
	output				end_bit_det_strb, 		// finished sending out command
	output				new_resp_packet_strb, 	// new resp. packet is available
	output				new_r2_packet_strb,
   output 	[47:0] 	resp_packet,
	output 	[135:0] 	resp2_packet												 
   );
	 
	// Registers 
	reg 		[47:0] 	cmd_pkt_reg;							
	reg					oe_reg;					// push out on cmd_out
	reg					snd_cmd_strb_z1;		// delay
	reg					snd_cmd_strb_z2;
	reg					snd_cmd_strb_z3;
	reg					snd_cmd_strb_z4;
	reg					cmd_out_reg;
	reg					cmd_in_z1;				// delay for cmd_in
	reg					resp_reg_z1;
	reg					resp_pkt_strt_strb; 	// response r1 packet has started
	reg					resp2_pkt_strt_strb; // response r2 packet has started
	reg 		[47:0] 	resp_pkt_reg;
	reg		[135:0]	r2_resp_packet_reg;
	reg					resp_packet_done_reg;
	reg					new_resp_pkt_rdy_z1;	// delay
	
	// Wires
	wire		[7:0]		resp_pkt_cnt;		// Counts how many bits in response pkt.
	wire		[7:0]		resp2_pkt_cnt;
	wire					new_resp_pkt_rdy;	// new response packet is ready
	wire					new_resp2_pkt_rdy;// new response packet is ready 
	wire					fin_cmd_out;		// finish sending out command on cmd_out

	////////////////////////////////////////////////////////////////////////////
	
	////////////////////////////////////////////////////////////////////////////
	// Initialize regs.
	initial			
	begin
		cmd_pkt_reg 			<= {48{1'b1}};
		cmd_in_z1				<= 1'b1;		
		cmd_out_reg				<= 1'b1;
		cmd_out					<= 1'b1;
		oe_reg					<= 1'b0;	
		snd_cmd_strb_z1		<= 1'b0;	
		snd_cmd_strb_z2		<= 1'b0;	 
		snd_cmd_strb_z3		<= 1'b0;	 
		snd_cmd_strb_z4		<= 1'b0;	
		resp_reg_z1				<= 1'b0;
		resp_pkt_strt_strb	<= 1'b0;
		resp2_pkt_strt_strb	<= 1'b0;
		resp_pkt_reg 			<= {48{1'b0}};
		r2_resp_packet_reg	<= {136{1'b0}};
		resp_packet_done_reg	<= 1'b0;			
		new_resp_pkt_rdy_z1	<= 1'b0;
	end
	////////////////////////////////////////////////////////////////////////////
	assign end_bit_det_strb = fin_cmd_out;
	
	// Set up delays.
	always@(posedge sd_clk)		
	begin
		if (reset) begin		  	  
         cmd_in_z1 			<= 1'b1;	
			snd_cmd_strb_z1	<= 1'b0;	
			snd_cmd_strb_z2	<= 1'b0;	
			snd_cmd_strb_z3	<= 1'b0;	
			snd_cmd_strb_z4	<= 1'b0;
		end
		else begin																		
         cmd_in_z1 			<= cmd_in;		
			snd_cmd_strb_z1	<= snd_cmd_strb;
			snd_cmd_strb_z2	<= snd_cmd_strb_z1;
			snd_cmd_strb_z3	<= snd_cmd_strb_z2;
			snd_cmd_strb_z4	<= snd_cmd_strb_z3;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////
	// Start of sending command.

	//Capture and Shift (left) the data, MSB first.
	always@(posedge sd_clk)
	begin
		if (reset) begin
			//cmd_pkt_reg 		<= {48{1'b0}};
			cmd_pkt_reg 		<= {48{1'b1}};
			cmd_out_reg			<= 1'b1;
		end
		else if (snd_cmd_strb_z2) begin
			// new packet when we get snd_cmd_strb
			cmd_pkt_reg 		<= cmd_packet;
			cmd_out_reg			<= 1'b1;	
		end
		else if (oe_reg) begin 
			cmd_pkt_reg[47:1] <= cmd_pkt_reg[46:0];// shift if output enable is on							  
			cmd_out_reg			<= cmd_pkt_reg[47];	// msbit first;
		end
//		else
//			cmd_pkt_reg 		<= cmd_pkt_reg;
	end		
										  
	// Output the data.
	always @(posedge sd_clk) 
	begin
      if (reset) 							
         cmd_out	<= 1'b1;		
		else
			cmd_out 	<= cmd_out_reg;
	end
	
	// Need to create a signal for the oe_reg.
	// Don't want to strobe it, need to carry it out
	// as long as we send the command.
	always @(posedge sd_clk) 
	begin
		if(reset) 
         oe_reg 	<= 1'b0;	
		else if (snd_cmd_strb_z4) 
         oe_reg 	<= 1'b1;
		else if (fin_cmd_out) 
			oe_reg 	<= 1'b0;
		else
			oe_reg	<=	oe_reg;						
	end
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// Need 48 clocks to push out the cmd_packet on to the cmd_out line.
	//-------------------------------------------------------------------------
	defparam cmdoutCntr.dw 	= 8;
	defparam cmdoutCntr.max	= 8'h31;//8'h2F;	
	//-------------------------------------------------------------------------
	CounterSeq cmdoutCntr(
		.clk(sd_clk), 	// sd clock 
		.reset(reset),	
		.enable(1'b1), 	
		.start_strb(snd_cmd_strb_z4), 	 	
		.cntr(), 
		.strb(fin_cmd_out)            
	);	 	
	// End of sending command.
	////////////////////////////////////////////////////////////////////////////
	
	////////////////////////////////////////////////////////////////////////////
	// Start of listening to response.	 
	// Assigning outputs
	assign resp_packet 				= resp_pkt_reg; 		 // new response packet
	assign resp2_packet 				= r2_resp_packet_reg; // new response packet
	// last bit of resp. detected
	assign new_resp_packet_strb 	= new_resp_pkt_rdy_z1;	 
	assign new_r2_packet_strb 		= new_resp2_pkt_rdy;
	
	/////////////////////////////////////////////////////
	
	// Create delay.
	always@(posedge sd_clk)
	begin
		if (reset)
			new_resp_pkt_rdy_z1	<= 1'b0; 				 
		else 
			new_resp_pkt_rdy_z1	<= new_resp_pkt_rdy;
	end
	
	// Create falling edge strobe to start counter.
	// This is to count the amount of clocks that passed
	// since we started to capture the response.
	// We need to stop at 48 clocks for R1 response.
	always@(posedge sd_clk)
	begin
		if (reset)
			resp_pkt_strt_strb 		<= 1'b0;
		else if (!r2_resp_enb) begin
					// falling edge, not output enable and response packet count
					// must be zero.  Not in the middle of counting.		 
			//if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp_pkt_cnt == 0))
			if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp_pkt_cnt == 0))
				resp_pkt_strt_strb 	<= 1'b1;	
			else
				resp_pkt_strt_strb 	<= 1'b0;	
		end
		else
			resp_pkt_strt_strb 		<= 1'b0;
		/* use this technique to create a strobe. */
	end
	
	// Create falling edge strobe to start counter.
	// This is to count the amount of clocks that passed
	// since we started to capture the response.
	// We need to stop at 136 clocks for R2 response.
	always@(posedge sd_clk)
	begin
		if (reset)
			resp2_pkt_strt_strb 		<= 1'b0;
		else if (r2_resp_enb) begin
					// falling edge                         					  
			//if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp2_pkt_cnt == 0))
			if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp2_pkt_cnt == 0))
				resp2_pkt_strt_strb 	<= 1'b1;
			else
				resp2_pkt_strt_strb 	<= 1'b0;
		end
		/* use this technique to create a strobe. */
	end	 
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// We'll create a strobe to start listening to the response. 
	// This usually lasts for 48 clocks for R1 response.
	//-------------------------------------------------------------------------
	defparam cntR1RespCntr.dw 	= 8;
	// 0-45 counts, tweak, if we count too much, we'll end up shifting the 
	// response packet too much.  The counter actually starts to count after
	// we detect a falling edge of cmd_in.
	defparam cntR1RespCntr.max	= 8'h2C;	
	//-------------------------------------------------------------------------
	CounterSeq cntR1RespCntr(
		.clk(sd_clk), 								// Clock input 400 kHz 
		.reset(reset | new_resp_pkt_rdy),	// GSR and reset when done
		.enable(~r2_resp_enb), 		
		// start count at falling edge but only when count is at 0.
		//.start_strb((!cmd_in && cmd_in_z1) && (resp_pkt_cnt == 0)),
		.start_strb(resp_pkt_strt_strb), 	 	
		.cntr(resp_pkt_cnt), 
		.strb(new_resp_pkt_rdy)            
	);
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// We'll create a strobe to start listening to the response. 
	// This usually lasts for 136 clocks for R2 response.
	//-------------------------------------------------------------------------
	defparam cntR2RespCntr.dw 	= 8;
	defparam cntR2RespCntr.max	= 8'h84; //	0-132 counts, tweak
	//-------------------------------------------------------------------------
	CounterSeq cntR2RespCntr(
		.clk(sd_clk), 								// Clock input 400 kHz 
		.reset(reset | new_resp2_pkt_rdy),	// GSR and reset when done
		.enable(/*r2_resp_enb*/ 1'b1), 	
		.start_strb(resp2_pkt_strt_strb), 	 	
		.cntr(resp2_pkt_cnt), 
		.strb(new_resp2_pkt_rdy)            
	);
	
	// Create a latch to stop shifting the resp_pkt_reg after we have finished
	// collecting the data.
	always@(posedge sd_clk)
	begin
		if (reset)
			resp_packet_done_reg	<= 1'b0; 				 
		else if (new_resp_pkt_rdy | new_resp2_pkt_rdy)
			resp_packet_done_reg	<= 1'b1;						  
		else if (resp_pkt_strt_strb | resp2_pkt_strt_strb)
			resp_packet_done_reg	<= 1'b0;
	end
	
	// Create a latch to stop shifting the resp_pkt_reg after we have finished
	// collecting the data.  Or we could create a strobe and in the main caller
	// we need to store the new response packet when this strobe occurs.  We may
	// need to do this to remove the warning in the synthesis step.
	/*always@(reset, resp_pkt_strt_strb, resp2_pkt_strt_strb, new_resp_pkt_rdy, 
				new_resp2_pkt_rdy, resp_packet_done_reg)
	begin
		if (reset) begin
			resp_packet_done_reg	<= 1'b0; 		
		end
		else if (new_resp_pkt_rdy | new_resp2_pkt_rdy) begin
			resp_packet_done_reg	<= 1'b1;
		end
		else if (resp_pkt_strt_strb | resp2_pkt_strt_strb) begin
			resp_packet_done_reg	<= 1'b0;
		end
		else begin
			resp_packet_done_reg	<= 1'b0;
		end
	end*/
	
	// Shift (left) the data in for r1 response.
	always@(posedge sd_clk)
	begin
		if (reset) 
			resp_pkt_reg 			<= {48{1'b0}}; 									
		// The first time we detect the response, we need to initialize the 
		// response register so we can do the shifting cleanly.
		// Fallen edge for cmd_in.														
		//else if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp_pkt_cnt == 0))
		else if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp_pkt_cnt == 0))
			resp_pkt_reg 			<= {48{1'b0}}; // reset r1 resp packet reg
		// Shift if output enable is off,  
		// we are not done with the packet (48 counts) and
		// we are not expecting R2 response.  The last condition is needed
		// because when we reached packet count of 46, we need to stop shifting.
		// If we continue, we will shift one bit too much.
		// Also, this is for r1 response or any response that has only
		// 48 bits.											
 		//else if (!r2_resp_enb && !oe_reg && (!resp_packet_done_reg) /*&&
//					(!resp_pkt_cnt != 8'h2d)*/) begin
 		else if (!r2_resp_enb && !oe_reg && (!resp_packet_done_reg) /*&&
					(!resp_pkt_cnt != 8'h2d)*/) begin
			resp_pkt_reg[0] 		<= cmd_in;
			resp_pkt_reg[47:1] 	<= resp_pkt_reg[46:0];	
		end
	end
	
	// Shift (left) the data in for the R2 response.
	always@(posedge sd_clk)
	begin
		if (reset)
			r2_resp_packet_reg			<= {136{1'b0}};										
		// The first time we detect the response, we need to initialize the 
		// response register so we can do the shifting cleanly.				 
		//else if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp2_pkt_cnt == 0))
		else if ((!cmd_in && cmd_in_z1) && !oe_reg && (resp2_pkt_cnt == 0)) 		 
			r2_resp_packet_reg			<= {136{1'b0}}; // reset r2 resp packet reg
		// Shift if output enable is off,  
		// and we are not done with the packet (136 counts).
		// Also, this is for the R2 response.			  
 		//else if (r2_resp_enb && !oe_reg && (!resp_packet_done_reg) /*&&
//					(!resp2_pkt_cnt != 8'h86)*/) begin
 		else if (r2_resp_enb && !oe_reg && (!resp_packet_done_reg) /*&&
					(!resp2_pkt_cnt != 8'h86)*/) begin
			r2_resp_packet_reg[0] 	  	<= cmd_in;
			r2_resp_packet_reg[135:1] 	<= r2_resp_packet_reg[134:0];	
		end
	end
	
endmodule
