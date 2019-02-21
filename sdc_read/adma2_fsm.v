`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company:       
// Engineer:      VDT
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
//						Section 1.13.5 ADMA2 States.	This state machine will fetch
//       	      one descriptor line at a time and send one block of data.
//                It will do this 16 times for 16 blocks of data.
//						One block of data is 512 bytes of data.
//
// Revision:      07/20/2016
//                Implemented multiple descriptor tables.  Before, for single 
//                block transfer, did not use multiple descriptor tables.
//                01/14/2017
//                We will send out cmd13 to poll the status of the sd card.
//                If it is ready to receive the next block of data, then we
//                will send the next block of data.  It seems that waiting 
//                for the card to release the data line is not reliable.
//                02/07/2017
//                Try to wait about 20 ms after we write the block of data,
//                then look to see if the card is still busy.  If it is busy
//                try to wait another 20 ms until we get a no busy signal.
//                We try this for up to 10 times before sending out the cmd12
//                to stop the transmission.
//                02/12/2017
//                After finishing with all blocks, wait x amount of time before
//                sending out cmd12.
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module adma2_fsm(
   input 	      clk,			
   input 		   reset,	
   // This strobe will be ready after we fill up the sdc data fifo.
   input 		   strt_adma_strb, 	         // ready to start the data transfer		 
	input 		   continue_blk_send,		   											 			
	input				dat_tf_done,		      	// Finished with data transfer from fifo.
   input          wr_busy,                   // SD card is busy writing to its memory.
	output reg     des_fifo_rd_strb,          // fetch descriptor from descriptor fifo
   input [63:0]   des_rd_data,               // descriptor item
	output reg     adma_system_addr_strb,     // from host controller       
	output		   adma_sar_inc_strb,												  		     	 
   output reg     adma2_rdy_to_snd_dat_strb, // ready for first word of data of each block
   output reg     snd_cmd13_strb,            // send cmd13 to poll for card ready
   input [15:0]   transfer_mode,
   input          fin_cmnd_strb,             // finished sending out cmd13, ready to check response
	output         snd_auto_cmd12_strb,       // send auto cmd12 to stop multiple blocks transfer
   input          card_rdy_bit               // this bit holds the card status bit for card ready
   //output reg		strt_fifo_strb		      // start to save data into the fifo.		
	);	
												 														   
	reg	         adma_sar_inc_strb_reg;	// increments adma sys. addr. reg.
   reg            snd_auto_cmd12_strb_reg;// send out auto cmd12 for multiple blocks transfer
	//reg            issue_abort_cmd_reg;    // need to indicate cmd12 is a command with busy response
   reg [5:0]      des_attr;
   reg            des_fifo_rd_strb_z1; // delay
   reg            des_fifo_rd_strb_z2; // delay
	reg            des_fifo_rd_strb_z3; // delay
	reg            des_fifo_rd_strb_z4; // delay
	reg            des_fifo_rd_strb_z5; // delay
	reg            des_fifo_rd_strb_z6; // delay
   reg            wr_busy_z1;          // delay
   reg            rdy_to_chk;          // ready to check for cmd13 response flag   
   reg            timeout;             // timeout flag waiting for sd card ready response
   reg            card_rdy;            // card is ready to be written again
   reg            card_rdy_z1;         // card is ready to be written again
   reg            strt_wait_cntr;      // Start the 20 ms wait counter
   reg [3:0]      wait_cnt;            // Counts how many time we wait for 20 ms
   
   //wire           rdy_to_chk_strb;     // ready to check for cmd13 response strobe
   wire           timeout_strb;        // timeout strobe waiting for sd card ready response
   wire [27:0]    timeoutCnt;          // time out counts when we start to send out cmd13
   wire           done_wait_strb;        // Strobe that 20 ms is done
   
   // Initialize sequential logic
   initial			
	begin								
      des_attr                   <= {6{1'b0}};					  
		//strt_fifo_strb			   <= 1'b0;	  
		des_fifo_rd_strb	         <= 1'b0;	  
		adma_sar_inc_strb_reg	   <= 1'b0;		
      snd_auto_cmd12_strb_reg    <= 1'b0;		
      //issue_abort_cmd_reg        <= 1'b0;
		adma_system_addr_strb	   <= 1'b0;	     	 
      adma2_rdy_to_snd_dat_strb  <= 1'b0;
		des_fifo_rd_strb_z1		   <= 1'b0; 
		des_fifo_rd_strb_z2		   <= 1'b0; 
		des_fifo_rd_strb_z3		   <= 1'b0; 
		des_fifo_rd_strb_z4			<= 1'b0; 
		des_fifo_rd_strb_z5			<= 1'b0; 
		des_fifo_rd_strb_z6			<= 1'b0;	
		wr_busy_z1			         <= 1'b0;	
		rdy_to_chk			         <= 1'b0;	
		timeout			            <= 1'b0;	
		snd_cmd13_strb	            <= 1'b0;	
		card_rdy	                  <= 1'b0;	
		card_rdy_z1                <= 1'b0;	
		strt_wait_cntr             <= 1'b0;	
		wait_cnt                   <= 4'h0;	
	end
	
	// Set up delays.
	always@(posedge clk)
	begin
		if (reset) begin
			des_fifo_rd_strb_z1	<= 1'b0; 
			des_fifo_rd_strb_z2	<= 1'b0; 
			des_fifo_rd_strb_z3	<= 1'b0; 
			des_fifo_rd_strb_z4	<= 1'b0; 
         des_fifo_rd_strb_z5	<= 1'b0; 
         des_fifo_rd_strb_z6	<= 1'b0; 
         wr_busy_z1			   <= 1'b0;		
         card_rdy_z1          <= 1'b0;
		end
		else begin
			des_fifo_rd_strb_z1	<= des_fifo_rd_strb; 
			des_fifo_rd_strb_z2	<= des_fifo_rd_strb_z1;
			des_fifo_rd_strb_z3	<= des_fifo_rd_strb_z2;
			des_fifo_rd_strb_z4	<= des_fifo_rd_strb_z3;
			des_fifo_rd_strb_z5	<= des_fifo_rd_strb_z4;
			des_fifo_rd_strb_z6	<= des_fifo_rd_strb_z5; 
         wr_busy_z1			   <= wr_busy;	
         card_rdy_z1          <= card_rdy;
		end
	end   
	
	// Assign registers to outputs.
   assign snd_auto_cmd12_strb = snd_auto_cmd12_strb_reg;
	//assign issue_abort_cmd	   = issue_abort_cmd_reg;
	// for the sd host controller memory map												  
	assign adma_sar_inc_strb	= adma_sar_inc_strb_reg;
    
	// Parse for desciptor attribute
   always @(posedge clk) begin
      if (reset)
         des_attr <= {6{1'b0}};
      else if (des_fifo_rd_strb_z5) // wait for 5 clocks
         des_attr <= des_rd_data[5:0];
      //else
        // des_attr <= des_attr;
   end			
	
	/////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// We will wait for 50 clocks before we start to check for the card ready
   // signal from the sd card.
	//-------------------------------------------------------------------------
//	defparam rdyToChkCntr.dw 	= 7;
//	defparam rdyToChkCntr.max	= 7'h32;	
//	//-------------------------------------------------------------------------
//	CounterSeq rdyToChkCntrCntr(
//		.clk(clk), 	 
//		.reset(reset),	
//		.enable(1'b1), 	
//		.start_strb(snd_cmd13_strb), 	 	
//		.cntr(), 
//		.strb(rdy_to_chk_strb)            
//	);	 
    
	// Set when we are ready to check for the card status
   always @(posedge clk) begin
      if (reset || adma2_rdy_to_snd_dat_strb)
         rdy_to_chk <= 1'b0;
      else if (fin_cmnd_strb && (timeoutCnt > 28'h0000000))
         rdy_to_chk <= 1'b1;
   end	
    
	// Card status ready bit is set
   always @(posedge clk) begin
      if (reset || adma2_rdy_to_snd_dat_strb)
         card_rdy <= 1'b0;
      else if (fin_cmnd_strb && (timeoutCnt > 28'h0000000) && card_rdy_bit)
         card_rdy <= 1'b1;
   end	

	//-------------------------------------------------------------------------
	// If we waited for 1 second and the card is not ready yet,
	// go to the stop state.
	//-------------------------------------------------------------------------
	defparam timeoutCntr.dw 	= 28;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam timeoutCntr.max	= 28'h2FAF080;	
	//-------------------------------------------------------------------------
	CounterSeq timeoutCntr(
		.clk(clk), 		                                             // Clock input 50 MHz 
		.reset(reset | timeout_strb | (!card_rdy_z1 && card_rdy)),	// 
		.enable(1'b1), 	
		// start the timing
		.start_strb(snd_cmd13_strb),   	 	
		.cntr(timeoutCnt), 
		.strb(timeout_strb) 
	);	
    
	// Set when the time has ran out to wait for the sd card response.
   always @(posedge clk) begin
      if (reset || snd_cmd13_strb)
         timeout <= 1'b0;
      else if (timeout_strb)
         timeout <= 1'b1;
   end	

	//-------------------------------------------------------------------------
	// After we send out one block of data, wait for 20 ms before checking
	// to see if card is ready.
	//-------------------------------------------------------------------------
	//defparam waitCntr.dw 	= 20; // 20 bits; for simulation
	defparam waitCntr.dw 	= 24; // 24 bits; for integration
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	//defparam waitCntr.max	= 20'hF4240; // 20 ms = 1M cnts - use this for simulation.	
	defparam waitCntr.max	= 24'h2DC6C0; // 60 ms = 3M cnts - use this for integration (real thing).
	//-------------------------------------------------------------------------
	CounterSeq waitCntr(
		.clk(clk), 		                  // Clock input 50 MHz 
		.reset(reset | done_wait_strb),	// 
		.enable(1'b1), 	
		// start the timing
		.start_strb(strt_wait_cntr),   	 	
		.cntr(), 
		.strb(done_wait_strb) 
	);		
	
	// ADMA2 State Machine
	// Here we start to fetch the data from the System Memory RAM
	// and send it to the SD card.  We will stop when we come to
	// the last data set (block).
   parameter state_stop 	      = 15'b_0000_0000_0000_0001; 	// stop dma
   parameter state_fds 		      = 15'b_0000_0000_0000_0010;	// fetch descr
   parameter state_fds_read      = 15'b_0000_0000_0000_0100;	// check descr for valid
   parameter state_cadr 	      = 15'b_0000_0000_0000_1000;	// change address
   parameter state_cadr_end_0    = 15'b_0000_0000_0001_0000;	// not finished with descriptor
   parameter state_cadr_end_1    = 15'b_0000_0000_0010_0000;	// finish with descriptor
   parameter state_tfr		      = 15'b_0000_0000_0100_0000;	// transfer data 
   parameter state_tfr_wt	      = 15'b_0000_0000_1000_0000;	// transfer data wait
   parameter state_auto_cmd12    = 15'b_0000_0001_0000_0000;	// send auto cmd12
   parameter state_auto_cmd12_wt = 15'b_0000_0010_0000_0000;	// send auto cmd12 wait
   parameter state_qry_stat      = 15'b_0000_0100_0000_0000;	// send cmd13 to poll for card ready
   parameter state_chk_stat      = 15'b_0000_1000_0000_0000;	// wait for cm13 response
   parameter state_pre_wait      = 15'b_0001_0000_0000_0000;	// start the wait countr strobe
   parameter state_wait_20ms     = 15'b_0010_0000_0000_0000;	// wait for 20 ms
   parameter state_chk_busy      = 15'b_0100_0000_0000_0000;	// check D0 line for busy

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_stop" *) 
	reg [14:0] state = state_stop;

   always@(posedge clk)
      if (reset) begin
         state 								   <= state_stop;    
         //<outputs> <= <initial_values>;				
			//strt_fifo_strb						   <= 1'b0;	     
         des_fifo_rd_strb	               <= 1'b0;   
			adma_sar_inc_strb_reg				<= 1'b0;	
         adma_system_addr_strb	      	<= 1'b0;	     	 
         adma2_rdy_to_snd_dat_strb        <= 1'b0;
         snd_auto_cmd12_strb_reg          <= 1'b0;
         snd_cmd13_strb	                  <= 1'b0;
         strt_wait_cntr                   <= 1'b0;
         wait_cnt                         <= 4'h0;	
      end
      else
         (* PARALLEL_CASE *) case (state)
            state_stop : begin
               if (strt_adma_strb | continue_blk_send)
                  state 					   <= state_fds;
               else if (!strt_adma_strb | !continue_blk_send)
                  state 				      <= state_stop;	             
               else                          
                  state 					   <= state_stop;   
               //<outputs> <= <values>;   		  	     
					//strt_fifo_strb				   <= 1'b0;	     
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;	     	 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;   
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;	
            end                              
            state_fds : begin                
               state 						   <= state_fds_read;   
               //<outputs> <= <values>;   		  									   
					//strt_fifo_strb				   <= 1'b0;	     
               // strobe to get descriptor item
               // each strobe will increment the fifo by one address
               des_fifo_rd_strb	         <= 1'b1;          
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;	     	 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;	 		   
            end  													
            state_fds_read : begin
               if (des_fifo_rd_strb_z6) begin         // don't check until after 6 clocks    
                  if (des_attr[0])                    // if valid = 1   
                     state 		         <= state_cadr;         
                  else                       
                     state 				   <= state_stop;   
               end
               else                   
                  // may want a timeout here, could get stuck
                  state 					   <= state_fds_read;   
               //<outputs> <= <values>;	 			
					//strt_fifo_strb				   <= 1'b0;	     
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;   
               adma_system_addr_strb		<= 1'b0;	     	 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;	
            end
            state_cadr : begin    
               if (!des_attr[1] && ~des_attr[5])      // if end = 0 and tran = 0   
                  state 		            <= state_fds;
               if (des_attr[1] && ~des_attr[5])       // if end = 1 and tran = 0   
                  state 		            <= state_stop;
               if (des_attr[5])                       // if tran = 1   
                  state 		            <= state_tfr;   
               else                    
                  state 				      <= state_stop;  
               //<outputs> <= <values>;		 		
					//strt_fifo_strb				   <= 1'b0;	      
               des_fifo_rd_strb	         <= 1'b0;
               adma_sar_inc_strb_reg      <= 1'b0;
               adma_system_addr_strb		<= 1'b0;	     	 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;	
            end                           
            state_cadr_end_0 : begin      
               state 		               <= state_tfr; 
               //<outputs> <= <values>;		 		
					//strt_fifo_strb				   <= 1'b0;	      
               des_fifo_rd_strb	         <= 1'b0; 
               // increment the sar in the host controller reg. map
               adma_sar_inc_strb_reg      <= 1'b1; 
               adma_system_addr_strb		<= 1'b0;	 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;	
            end                           
            state_cadr_end_1 : begin       
               state 		               <= state_stop;  
               //<outputs> <= <values>;		 		
					//strt_fifo_strb				   <= 1'b0;	      
               des_fifo_rd_strb	         <= 1'b0;   
               adma_sar_inc_strb_reg      <= 1'b0;    // does not need to increment   
               adma_system_addr_strb		<= 1'b0;		 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
            end                           
            state_tfr : begin   
					// Here we start to send out the data to the sd card.
					// Or read data from the sd card.  We will only transfer the
					// data only if the D0 line is not busy.          
               state 						   <= state_tfr_wt;   
               //<outputs> <= <values>;  
					snd_cmd13_strb				   <= 1'b0; 
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               // Ready to send out the next block of data.
               adma2_rdy_to_snd_dat_strb  <= 1'b1;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
            end	                        
            state_tfr_wt : begin
               // We will wait here for each block of data to be sent or read.
               // After sending each block, poll to see if the card is ready to
               // take another block.  When the card is ready for the next block,
               // this state will go back to state state_fds until we are done
               // with the multiple blocks transfer, end = 0 and stop = 0.  
               // If end = 1 or stop =1 go to state_auto_cmd12.
               // This will send cmd12 to stop the write block command.
               // If end = 0, poll for status.
               // Start to poll after we have finished sending out one block of data.
               // 2/2/17  We will not do polling, instead, we wait for x amount of time.
               // After that, we will see if the sd card has released the line.
               if (/*(!des_attr[1]) &&*/ dat_tf_done /*&& (!wr_busy && wr_busy_z1)*/)   // falling edge
                  state 					   <= state_pre_wait;					
               // if end = 1.  Wait before sending command 12.
					else if ((des_attr[1]) && dat_tf_done/*&& (!wr_busy && wr_busy_z1)*/ /*&& (~transfer_mode[2])*/)
                  state 					   <= state_pre_wait;       
               // if card is not busy and end = 1 /*and cmd12 enabled*/
					//else if ((des_attr[1]) && (!wr_busy && wr_busy_z1) && transfer_mode[2])
               // Don't go to stop directly.  Need to send auto cmd12 first.
                  //state 					   <= state_auto_cmd12;       
               else                          
                  state 					   <= state_tfr_wt;                          // else wait, may need a timeout here   
               //<outputs> <= <values>;   		  					     
					//strt_fifo_strb					<= 1'b0;             // from system memory ram	    
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;		 		     
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
            end
            state_qry_stat : begin   
					// Send out cmd13 to see if card is ready for next data.          
               state 						   <= state_chk_stat;   
               //<outputs> <= <values>;   
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b1;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
               end
            state_chk_stat : begin   
					// Stay here and wait for ready from sd card.
               // If response is not ready and we have not time out,
               // resend cmd13.  If time has ran out and the card
               // is not ready, go to stop state.
               // If card is ready, go to
               // state_fds to start another transfer.
               if (!card_rdy && !timeout && rdy_to_chk /* && !des_attr[1]*/)
                  state 						<= state_qry_stat; 
               else if (!card_rdy && timeout && rdy_to_chk)
                  state 						<= state_stop;     
               else if (card_rdy /*&& !timeout*/ && rdy_to_chk)
                  state 						<= state_fds;
               else
                  state 						<= state_chk_stat;
               //<outputs> <= <values>;  
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
            end										  
            state_auto_cmd12 : begin   
					// Send out cmd12 when finished with multiple send blocks          
               state 						   <= state_auto_cmd12_wt;   
               //<outputs> <= <values>;  
					//strt_fifo_strb				   <= 1'b1; // from system memory ram
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               // Ready to send out the next block of data.
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b1;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
            end										  
            state_auto_cmd12_wt : begin             
               state 						   <= state_stop;   
               //<outputs> <= <values>;  
					//strt_fifo_strb				   <= 1'b1; // from system memory ram
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               // Ready to send out the next block of data.
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= 4'h0;
            end										  
            state_pre_wait : begin             
               state 						   <= state_wait_20ms;   
               //<outputs> <= <values>;  
					//strt_fifo_strb				   <= 1'b1; // from system memory ram
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               // Ready to send out the next block of data.
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b1;
               wait_cnt                   <= wait_cnt + 4'h1;
            end						
            state_wait_20ms : begin   
					// Stay here and wait for x amount of time.
               // When done, go check to see if the sd card is not busy.
               if (done_wait_strb && !des_attr[1])
                  state 						<= state_chk_busy;
					// Stay here and wait for x amount of time.
               // When done, and end of blocks transfer, go to send cmd12
               else if (done_wait_strb && des_attr[1])
                  state 						<= state_auto_cmd12;
               else
                  state 						<= state_wait_20ms;
               //<outputs> <= <values>;  
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= wait_cnt;
            end
            state_chk_busy : begin   
               // Check to see if the sd card is not busy.
               if (!wr_busy)
                  state 						<= state_fds;
               // If card is busy and we haven't tried it ten times.
               else if (wr_busy && (wait_cnt < 10))
                  state 						<= state_pre_wait;
               // If card is busy and we have tried it ten times, send cmd12.
               else if (wr_busy && (wait_cnt >= 9))
                  state 						<= state_auto_cmd12;
               //<outputs> <= <values>;  
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;
               wait_cnt                   <= wait_cnt;
            end										  
            default: begin  // Fault Recovery
               state 						   <= state_stop;   
               //<outputs> <= <values>;   				   
					//strt_fifo_strb				   <= 1'b0;
               des_fifo_rd_strb	         <= 1'b0;   
					adma_sar_inc_strb_reg	   <= 1'b0;		   
               adma_system_addr_strb	   <= 1'b0;			     	 
               adma2_rdy_to_snd_dat_strb  <= 1'b0;
               snd_auto_cmd12_strb_reg    <= 1'b0;
               snd_cmd13_strb	            <= 1'b0;
               strt_wait_cntr             <= 1'b0;   
               wait_cnt                   <= 4'h0;
				end
         endcase
							

endmodule
