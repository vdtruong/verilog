`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:50:11 04/23/2014 
// Design Name: 
// Module Name:    GetPUCData 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 	This module collects data for the sdc host bus fifo.
//                         We only need 63 data items.  Whenever the host bus is
//                         ready for data, this module will increase to the next
//                         read address.
//									
//
//////////////////////////////////////////////////////////////////////////////////
module GetPUCData(
    input 					clk,
    input 					reset,
	 // Not needed since the rdy_for_nxt_pkt from the time stamp
	 // will determine the strobe for the first rd_addr.
	 //input					strt_puc_fifo_strb,// start collecting data for fifo	 
    output reg	[15:0]	rd_addr,			    // address to read data from bus arbitrator
    output reg				rd_strb,			    // strobe to read data from bus arbitrator
	 // Data get packed into 64 bits word here.  Data from bus arbitrator.
    input 		[35:0] 	rd_data,			    // data from bus arbitrator
    input 					rd_rdy_strb,	    // strobe that data is ready	 
    output reg	[63:0]	puc_data,		    // 
    output reg				puc_data_strb,		 // two clocks after rd_rdy_strb 
	 input               rdy_for_nxt_pkt	 // ready for next packet (fifo_data) from puc.	 
    );
	 
	// Registers
	reg            rdy_for_nxt_pkt_z1;
	reg				rd_rdy_strb_z1;
	reg				rd_rdy_strb_z2;
	reg				puc_data_strb_z1;
	//reg				done;				// done strobing for new data from puc
	
	// Wires
	wire	[7:0]		sel_rd_addr;	// select which address to read
	//wire				fin;				// finish with retreiving new puc data
	
	// Initialize sequential logic
	initial			
	begin												
		rd_addr					   <= {16{1'b0}};			
		rd_strb					   <= 1'b0;
		puc_data					   <= {64{1'b0}};
		rdy_for_nxt_pkt_z1    	<= 1'b0;
		rd_rdy_strb_z1		 	   <= 1'b0;
		rd_rdy_strb_z2		 	   <= 1'b0;
		puc_data_strb			 	<= 1'b0;
		puc_data_strb_z1		 	<= 1'b0;
		//done					 	   <= 1'b0;
	end     
	
	// Create delays.
	always@(posedge clk)
	begin
		if (reset) begin
		   rdy_for_nxt_pkt_z1    	<= 1'b0;
			rd_rdy_strb_z1		 	   <= 1'b0;
			rd_rdy_strb_z2		 	   <= 1'b0;
			puc_data_strb			 	<= 1'b0;
			puc_data_strb_z1		 	<= 1'b0;
		end
		else begin  
		   rdy_for_nxt_pkt_z1    	<= rdy_for_nxt_pkt;
			rd_rdy_strb_z1		 	   <= rd_rdy_strb;
			rd_rdy_strb_z2		 	   <= rd_rdy_strb_z1;
			puc_data_strb			 	<= rd_rdy_strb_z2;
			puc_data_strb_z1		 	<= puc_data_strb;
		end
	end
  
	//---------------------------------------------------------------
	// Counts to 63 addresses.
	//
	defparam ADDR_COUNTER.dw 	= 8;
	defparam ADDR_COUNTER.max 	= 8'h3F; 
	//---------------------------------------------------------------
	Counter ADDR_COUNTER 
	(
		.clk(clk),
		.reset(reset),
		// Get a new address at the beginning and
		// every time we send away the packet to
		// the fifo.
		.enable((/*strt_puc_fifo_strb_z1 || */rdy_for_nxt_pkt)/* && (!done)*/),
		.cntr(sel_rd_addr),
		.strb(/*fin*/)
	);		
	
	// We are done retreiving data from puc when we have used up
	// 64 addresses.
//	always@(posedge clk)
//	begin
//		if (reset) 
//			done 	<= 1'b0;
//		else if (fin)	     
//			done 	<= 1'b1;
//			// set a counter to turn off done
//			// instead of relying on strt_puc_fifo_strb?
//		else if (sel_rd_addr == 64'd63)      
//			done 	<= 1'b0;
//		else  
//			done 	<= done;
//	end
	
	// Strobe to read after we have increased the address.
	always@(posedge clk)
	begin
		if (reset) 
			rd_strb 	<= 1'b0;
//		else if (strt_puc_fifo_strb_z3)		      // may need to delay more     
//			rd_strb 	<= 1'b1;
		else if (rdy_for_nxt_pkt_z1 /*&& (!done)*/) 	// may need to delay more     
			rd_strb 	<= 1'b1;									// read from bus arbitrator
		else  
			rd_strb 	<= 1'b0;
	end
	
	// 
	always@(posedge clk)
	begin
		if (reset) 
			puc_data		<= {64{1'b0}};
		else if (rd_rdy_strb)     
			puc_data		<= {{28{1'b0}},rd_data};
		else  
			puc_data		<= puc_data;
	end
	
	// Select which address to read base on counter.
   always @(sel_rd_addr)
      case (sel_rd_addr)
         8'd1: 	rd_addr = 16'h0100;
         8'd2: 	rd_addr = 16'h0108;
         8'd3: 	rd_addr = 16'h0109;
         8'd4: 	rd_addr = 16'h010A;
         8'd5: 	rd_addr = 16'h010B;
         8'd6: 	rd_addr = 16'h010C;
         8'd7: 	rd_addr = 16'h010D;
         8'd8: 	rd_addr = 16'h0110;
         8'd9: 	rd_addr = 16'h0112;
         8'd10: 	rd_addr = 16'h0114;
         8'd11: 	rd_addr = 16'h0116;
         8'd12: 	rd_addr = 16'h0118;
         8'd13: 	rd_addr = 16'h0119;
         8'd14: 	rd_addr = 16'h011C;
         8'd15: 	rd_addr = 16'h011D;
         8'd16: 	rd_addr = 16'h011E;
         8'd17: 	rd_addr = 16'h0127;
         8'd18: 	rd_addr = 16'h012E;
         8'd19: 	rd_addr = 16'h012F;
         8'd20: 	rd_addr = 16'h0134;
         8'd21: 	rd_addr = 16'h0135;
         8'd22: 	rd_addr = 16'h0136;
         8'd23: 	rd_addr = 16'h0137;
         8'd24: 	rd_addr = 16'h0138;
         8'd25: 	rd_addr = 16'h0144;
         8'd26: 	rd_addr = 16'h0160;
         8'd27: 	rd_addr = 16'h0161;
         8'd28: 	rd_addr = 16'h0166;
         8'd29: 	rd_addr = 16'h0174;
         8'd30: 	rd_addr = 16'h0175;
         8'd31: 	rd_addr = 16'h0176;
         8'd32: 	rd_addr = 16'h0177;
         8'd33: 	rd_addr = 16'h0178;
         8'd34: 	rd_addr = 16'h0179;
         8'd35: 	rd_addr = 16'h017A;
         8'd36: 	rd_addr = 16'h017B;
         8'd37: 	rd_addr = 16'h017C;
         8'd38: 	rd_addr = 16'h017D;
         8'd39: 	rd_addr = 16'h017E;
         8'd40: 	rd_addr = 16'h017F;
         8'd41: 	rd_addr = 16'h0200;
         8'd42: 	rd_addr = 16'h0201;
         8'd43: 	rd_addr = 16'h0202;
         8'd44: 	rd_addr = 16'h0203;
         8'd45: 	rd_addr = 16'h0204;
         8'd46: 	rd_addr = 16'h0205;
         8'd47: 	rd_addr = 16'h0208;
         8'd48: 	rd_addr = 16'h0209;
         8'd49: 	rd_addr = 16'h020A;
         8'd50: 	rd_addr = 16'h020B;
         8'd51: 	rd_addr = 16'h020C;
         8'd52: 	rd_addr = 16'h020D;
         8'd53: 	rd_addr = 16'h0218;
         8'd54: 	rd_addr = 16'h0219;
         8'd55: 	rd_addr = 16'h021A;
         8'd56: 	rd_addr = 16'h021B;
         8'd57: 	rd_addr = 16'h021C;
         8'd58: 	rd_addr = 16'h021D;
         8'd59: 	rd_addr = 16'h021E;
         8'd60: 	rd_addr = 16'h021F;
         8'd61: 	rd_addr = 16'h0239;
         8'd62: 	rd_addr = 16'h023A;
         8'd63: 	rd_addr = 16'h023B;
			default:	rd_addr = 16'h023B;
      endcase
					
endmodule
