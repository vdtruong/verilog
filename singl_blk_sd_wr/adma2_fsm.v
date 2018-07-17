`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:33:35 10/15/2012 
// Design Name: 
// Module Name:    adma2_fsm 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 	This modules takes care of the advanced dma state machine.
//						Section 1.13.5 ADMA2 States.	We will simplify this state 
//						machine greatly.  It will go around once and stops as
//        			it sends out 512 blocks of data.  We don't need to fetch
//						the descriptor item.  We will only have one descriptor
//						item, perhaps in the future we can expand this state machine
//						further to support more than one descriptor item.	We will
//						consider one item as one block of data.
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module adma2_fsm(
   input 				clk,
   input 				reset,
   input 				strt_adma_strb, 	// ready to start the data transfer
	input 				continue_blk_send,													 	 
	input					dat_tf_done,		// Finished with data transfer from fifo.
	output				adma_sar_inc_strb,												  
	output reg			strt_fifo_strb		// start to save data into the fifo.	
	);	
												 														   
	reg	adma_sar_inc_strb_reg;	// increments adma sys. addr. reg.	 
	
	// Initialize sequential logic
	initial			
	begin													  
		strt_fifo_strb				<= 1'b0;	  
		adma_sar_inc_strb_reg	<= 1'b0;		
	end
	
	// Assign registers to outputs.
	// for the sd host controller memory map												  
	assign adma_sar_inc_strb	= adma_sar_inc_strb_reg;
	
	// ADMA2 State Machine
	// Here we start to fetch the data from the System Memory RAM
	// and send it to the SD card.  We will stop when we come to
	// the last data set (block).
   parameter state_stop 	= 5'b0_0001; 	// stop dma
   parameter state_fds 		= 5'b0_0010;	// fetch descr
   parameter state_cadr 	= 5'b0_0100;	// change address
   parameter state_tfr		= 5'b0_1000;	// transfer data 
   parameter state_tfr_wt	= 5'b1_0000;	// transfer data

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_stop" *) 
	reg [4:0] state = state_stop;

   always@(posedge clk)
      if (reset) begin
         state 								<= state_stop;
         //<outputs> <= <initial_values>;				
			strt_fifo_strb						<= 1'b0;
			adma_sar_inc_strb_reg			<= 1'b0;		
      end
      else
         (* PARALLEL_CASE *) case (state)
            state_stop : begin
               if (strt_adma_strb | continue_blk_send)
                  state 					<= state_fds;
               else if (!strt_adma_strb | !continue_blk_send)
                  state 					<= state_stop;
               else
                  state 					<= state_stop;
               //<outputs> <= <values>;		  	  
					strt_fifo_strb				<= 1'b0;
					adma_sar_inc_strb_reg	<= 1'b0;
            end
            state_fds : begin
               state 						<= state_cadr;
               //<outputs> <= <values>;		  									
					strt_fifo_strb				<= 1'b0;
					adma_sar_inc_strb_reg	<= 1'b0;		
            end  													
            state_cadr : begin								
               state 						<= state_tfr;
               //<outputs> <= <values>;		 		
					strt_fifo_strb				<= 1'b0;
					// We'll only increment the adma system address here.
					// If in the future we should support the link attribute,
					// we may need to implement the Mealy state machine.
					adma_sar_inc_strb_reg	<= 1'b1;		
            end
            state_tfr : begin
               state 						<= state_tfr_wt;
               //<outputs> <= <values>;		  	  
					strt_fifo_strb				<= 1'b1; // from system memory ram
					adma_sar_inc_strb_reg	<= 1'b0;
            end										  
            state_tfr_wt : begin
					// Here we start to send out the data to the sd card.
					// Or read data from the sd card.  We will only transfer the
					// data only if the D0 line is not busy.
               if (dat_tf_done)
                  state 					<= state_stop;					
					else if (!dat_tf_done) 
                  state 					<= state_tfr_wt;
               else
                  state 					<= state_stop;
               //<outputs> <= <values>;		  					  
					strt_fifo_strb				<= 1'b0; // from system memory ram
					adma_sar_inc_strb_reg	<= 1'b0;		 		  
            end
            default: begin  // Fault Recovery
               state 						<= state_stop;
               //<outputs> <= <values>;				
					strt_fifo_strb				<= 1'b0;
					adma_sar_inc_strb_reg	<= 1'b0;		
				end
         endcase
							

endmodule
