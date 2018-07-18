`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:24:50 08/21/2012 
// Design Name: 
// Module Name:    sdc_controller_mod 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		This is the top module for the sd card controller.
//                   Should consider putting in time out clocks so we won't 
//                   get stuck in a certain state.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sdc_controller_mod(
	input 				clk,
   input 				reset, 	
	// manually initialize the sd card
	input					man_init_sdc_strb,	
	input					host_tst_cmd_strb,		// test cmd strb from host (ie, CMD8),
	// read register for host controller from PUC
	input		[11:0]	rd_reg_indx_puc,
	output	[35:0]	rd_reg_output_puc,		// export reg data to puc	
	input					wr_reg_man,					// write register manually from puc
	input		[35:0]	wreg_sdc_hc_reg_man,		// write reg. manually from puc, 0x0014 0xXXXXXXXXX
	input					start_data_tf_strb, 		// from puc or other host
	input					data_in_strb,				// from puc or other host
	input					last_set_of_data_strb,	// from puc or other host
	// Data from puc (or other host) per strobe. 
	// Also, use for test cmd (ie, CMD8).	
	// For the first 16 bits, it will be the
	// Command Register (00Eh) data. 
	// Used in conjunction with host_tst_cmd_strb. 
	input		[35:0]   data,	 
	
	// Following is for System Memory FIFO.	
	output				strt_fifo_strb,	// Ask PUC to fill up fifo.					 
	input					wr_b_strb,			// write PUC data to fifo
	input 	[63:0] 	fifo_data,			// data to be logged from PUC. 
	output            rdy_for_nxt_pkt,  // ready for next packet (fifo_data) from puc 
	
	// For sd card																 
	input 	[31:0] 	sdc_rd_addr,		// sd card read address.
	input 	[31:0] 	sdc_wr_addr,		// sd card write address.
   input    [35:0]   tf_mode,          // sd card transfer mode.
   //input    [5:0]    sdc_cmd_indx,     // command index for sdc command format
	
	input 				IO_SDC1_CD_WP,		// active low
	input					IO_SDC1_D0_in,
	output				IO_SDC1_D0_out,
	input					IO_SDC1_D1_in,
	output				IO_SDC1_D1_out,
	input					IO_SDC1_D2_in,
	output				IO_SDC1_D2_out,
	input					IO_SDC1_D3_in,
	output				IO_SDC1_D3_out,
	output        		IO_SDC1_CLK,
	input        		IO_SDC1_CMD_in,
	output        		IO_SDC1_CMD_out
   );	 
										  
  	localparam SM_MEM_SIZE 	= 64; // 64 elements   
  	localparam SM_ADDR_WD 	= 11; // address bits width for puc data fifo
  	localparam SM_DATA_WD 	= 64; // 64 bits each

	// Registers							 
	//reg	[7:0]		rd_ram_addr_in;
	//reg	[71:0]	sys_mem_input;	  
	reg				IO_SDC1_CD_WP_z1;		// delayed version
	reg 				IO_SDC1_CD_WP_strb;	// strobe to start counter
	reg				card_inserted_strb;	// after stabilized
	reg				card_removed_strb; 	// after stabilized
	reg				wr_reg_man_z1;			// delay
	reg				wr_reg_man_z2;			// delay
	reg				wr_reg_man_z3;			// delay
	reg				wr_reg_strb_man;		// write strobe manually from puc
	
	// Wires									 
	// for card debouncing counter, may need to reset to correct count
	wire				fin_2secs_strb;
	wire	[11:0]	rd_reg_index;
	wire	[127:0]	rd_reg_output;
	wire				wr_reg_strb;
	wire	[11:0]	wr_reg_index;
	wire 	[31:0]	wr_reg_output;
	wire 	[2:0]		reg_attr;
	wire	[7:0]		rd_ram_addr;
	wire 	[71:0]	output_ram_data;		 
	wire  [2:0]		kind_of_resp;  	   // based on cmd_index  
	wire				end_bit_det_strb;	   // finished sending out command to sd card
	wire				strt_adma_strb;	  
   wire           strt_snd_data_strb;  // First set of data to sd card.
	wire				new_dat_strb;		   // Ready for next word of data
	wire	[63:0]	sm_rd_data;			   // from the system memory RAM	
	wire	[15:0]	pkt_crc;				   // 512 bytes packet CRC	  
	wire				fifo_rdy_strb;		   // system memory fifo is ready to be used
   wire           des_fifo_rd_strb;    // strobe for the desctiptor item.
   wire  [63:0]   des_rd_data;         // desciptor item
   wire           snd_auto_cmd12_strb; // send auto cmd12 to stop multiple blocks transfer
   //wire           issue_abort_cmd;     // indicate an abort command is being sent
   wire           snd_cmd13_strb;      // send cmd13 to poll for card ready after a block write
   wire           fin_cmnd_strb;       // finished sending out command, ready to read response
	
	// Initialize sequential logic
	initial			
	begin												
		IO_SDC1_CD_WP_z1		<= 1'b0;				
		IO_SDC1_CD_WP_strb	<= 1'b0;		  
		card_inserted_strb	<= 1'b0;
		card_removed_strb		<= 1'b0;
		//rd_ram_addr_in			<= {8{1'b0}};
		//sys_mem_input			<= {72{1'b0}};
		wr_reg_man_z1			<= 1'b0;
		wr_reg_man_z2			<= 1'b0;
		wr_reg_man_z3			<= 1'b0;
		wr_reg_strb_man		<= 1'b0;
	end		 												  
	
	assign rd_reg_output_puc = rd_reg_output[35:0];
	
	// Create delays.
	always@(posedge clk)
	begin
		if (reset) begin
			IO_SDC1_CD_WP_z1		<= 1'b0;
			wr_reg_man_z1			<= 1'b0;
			wr_reg_man_z2			<= 1'b0;
			wr_reg_man_z3			<= 1'b0;
		end
		else begin		
			IO_SDC1_CD_WP_z1		<= IO_SDC1_CD_WP;
			wr_reg_man_z1			<= wr_reg_man;
			wr_reg_man_z2			<= wr_reg_man_z1;
			wr_reg_man_z3			<= wr_reg_man_z2;
		end
	end
	
	////////////////////////////////////////////////////////////////////////////
	// We'll take care of card detection here.
	////////////////////////////////////////////////////////////////////////////
	// Start the card detection strb if we have a change in signal level.
	// Need this strobe just to start the counter.
	always@(posedge clk)
	begin
		if (reset) 
			IO_SDC1_CD_WP_strb	<= 1'b0; 		// rising edge (disconnected) or falling edge (connected)
		else if ((IO_SDC1_CD_WP && !IO_SDC1_CD_WP_z1) | (!IO_SDC1_CD_WP && IO_SDC1_CD_WP_z1))  
			IO_SDC1_CD_WP_strb	<= 1'b1;
		else 
			IO_SDC1_CD_WP_strb	<= 1'b0;
	end
	
	//-------------------------------------------------------------------------
	// We need a generic 2 seconds counter to find out if the insertion or 
	// removal is stable.  
	//-------------------------------------------------------------------------
	defparam gen2secsCntr_u4.dw 	= 8;
	// Change this to reflect 2 seconds at 50 MHz.
	// It is not at 2 seconds now.
	defparam gen2secsCntr_u4.max	= 8'h27;	
	//-------------------------------------------------------------------------
	CounterSeq gen2secsCntr_u4(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		.start_strb(IO_SDC1_CD_WP_strb), // start the timing  	 	
		.cntr(), 
		.strb(fin_2secs_strb) 
	);
	
	// If the counter is finished and the card detection signal is still low,
	// set the card_inserted_strb to one.  This is to take care of debouncing.
	always@(posedge clk)
	begin
		if (reset) 
			card_inserted_strb	<= 1'b0;		
		else if (fin_2secs_strb && !IO_SDC1_CD_WP)  
			card_inserted_strb	<= 1'b1;
		else 
			card_inserted_strb	<= 1'b0;
	end
	
	// If the counter is finished and the card detection signal is still high,
	// set the card_removed_strb to one.  This is to take care of debouncing.
	always@(posedge clk)
	begin
		if (reset) 
			card_removed_strb	<= 1'b0;
		else if (fin_2secs_strb && IO_SDC1_CD_WP)  
			card_removed_strb	<= 1'b1;
		else 
			card_removed_strb	<= 1'b0;
	end
	// End of card detection.
	//////////////////////////////////////////////////////////////////////////// 
	
	//Create the wr_reg_strb_man based on the rising edge of wr_reg_man_z2.
	always@(posedge clk)
	begin
		if (reset)
			wr_reg_strb_man	<= 1'b0;		
		else if (wr_reg_man_z2 && !wr_reg_man_z3)	// rising edge 
			wr_reg_strb_man	<= 1'b1;
		else 
			wr_reg_strb_man	<= 1'b0;
	end
	
	// This module is the link between the puc and
	// the host controller module.  The host controller
	// is the physical layer to the sd card.	
  	defparam sd_host_bus_driver_u1.BRAM_SYSMEM_FILE	= "C:/FPGA_Design/sd_card_controller/src/BRAM_66_x_64.txt";
  	defparam sd_host_bus_driver_u1.BRAM_DES_FILE	   = "C:/FPGA_Design/sd_card_controller/src/BRAM_32_x_64.txt";
  	defparam sd_host_bus_driver_u1.SM_MEM_SIZE      = SM_MEM_SIZE;
  	defparam sd_host_bus_driver_u1.SM_ADDR_WD       = SM_ADDR_WD;
  	defparam sd_host_bus_driver_u1.SM_DATA_WD       = SM_DATA_WD;
	sd_host_bus_driver sd_host_bus_driver_u1(
		.clk(clk),											  												//	      input 
		.reset(reset),				 																		//		   input
		// Next three inputs for enable interrupts.												         
		.enb_int_strb(), 	// enable an interrupt from PUC												   input
		.enb_addr(), 		// memory map address														      input
		.enb_data(), 		// memory map data															      input
		// card has been inserted and stabilized													         
		.card_inserted_strb(card_inserted_strb), 													//		   input
		// card has been removed and stabilized													         
		.card_removed_strb(card_removed_strb),	  													//		   input
		// manually initialize the sd card															            
		.man_init_sdc_strb(man_init_sdc_strb),														//       input
		// test cmd strb from host (ie, CMD8)                                                  
      // strobe to send a sdc command, ie 0x0007.                                            
		.host_tst_cmd_strb(host_tst_cmd_strb),														//       input
		// read register from host controller from PUC											
		.end_bit_det_strb(end_bit_det_strb),														//       input
																												         
		.rd_reg_indx_puc(rd_reg_indx_puc),															//       input
		.wr_reg_man(wr_reg_man),								// from PUC								      
		.wr_reg_strb_man(wr_reg_strb_man),					// from PUC							//       input
		.wr_reg_index_man(wreg_sdc_hc_reg_man[27:16]),	// from PUC, 12 bits				//       input
		.wr_reg_output_man(wreg_sdc_hc_reg_man[15:0]),	// from PUC, 16 bits						   input
		.reg_attr_man(wreg_sdc_hc_reg_man[30:28]),		// from PUC, 3 bits	 			//       input
																													      
		// puc (or other host) starts a data transfer											         
		.start_data_tf_strb(start_data_tf_strb),													// 	   input
		// strobe for each set of data from puc (or other host)								         
		.data_in_strb(data_in_strb), 																	// 	   input
		// last set of data from puc (or other host)												         
		.last_set_of_data_strb(last_set_of_data_strb),											// 	   input
		.date(),  // date from puc	 																	//       input
		// Data from puc (or other host) per strobe. 											         
		// Also, use for test cmd (ie, CMD8).														         
		// For the first 16 bits, it will be the													         
		// Command Register (00Eh) data. 															         
		.data(data),																						//       input
		// for the sd host controller memory map													         
		.rd_reg_index(rd_reg_index), 	// output to host controller							         
		.rd_reg_input(rd_reg_output), // input from host controller							         
		.wr_reg_strb(wr_reg_strb), 	// output to host controller							         
		.wr_reg_index(wr_reg_index),	// output to host controller							         
		.wr_reg_output(wr_reg_output),// output to host controller							         
		.reg_attr(reg_attr),				// output to host controller							         
		// based on command index, output to host controller									         
		.kind_of_resp(kind_of_resp),																	         
																												         
		// Following is for System Memory FIFO.
      .strt_fifo_strb(strt_fifo_strb),                                              //       output
		.wr_b_strb(wr_b_strb),						// write puc data to fifo								input
		.fifo_data(fifo_data),						// data to be logged.							      input
		.rdy_for_nxt_pkt(rdy_for_nxt_pkt),     // ready for next packet (fifo_data) from puc.  output
		.fifo_rdy_strb(fifo_rdy_strb),	      // fifo is ready to be used					      output
		// Used by ADMA2 State Machine  
      .des_rd_strb(des_fifo_rd_strb),        // to fetch a descriptor item                   input
      .des_rd_data(des_rd_data),             // descriptor item                              output
		.strt_adma_strb(strt_adma_strb),			// Start the adma state machine.					   output
      // This signals fetches the first data word from the
      // data bram.
      .strt_snd_data_strb(strt_snd_data_strb),// First data set to sd card                   input
		// This signal fetches the consecutive data word from the
      // data bram.
      .new_dat_strb(new_dat_strb),				      // Next data from fifo.							input	      
		//.rd_ram_addr(rd_ram_addr),				      // 													input	      
		.sm_rd_data(sm_rd_data),					      // from the system memory ram					output      
		.sdc_wr_addr(sdc_wr_addr),					      // sdc write address								input      
		.pkt_crc(pkt_crc),							      // CRC for the 512 bytes packet.				output      
		.sdc_rd_addr(sdc_rd_addr),					      // sdc read address								input		   
		.r1_crc7_good_out(),							      // from sdc_cmd_mod								input      
      .tf_mode(tf_mode),                           // sd card transfer mode                  input      
      //.sdc_cmd_indx(sdc_cmd_indx),                 // command index for sdc command format   input      
      .snd_auto_cmd12_strb(snd_auto_cmd12_strb),   //                                        input
      .snd_cmd13_strb(snd_cmd13_strb),             // send out cmd13 to see if card is ready for next block    input
      .fin_cmnd_strb(fin_cmnd_strb)                // finished sending out cmd13, ready to read response       output
      //.issue_abort_cmd(issue_abort_cmd)            //                                        input
   );																											
																												
	// This module talks physically to the sd card.												
	// The host bus driver takes information from the puc										
	// and relays it to this module.  It also takes information								
	// from this module and relays it to the puc.												
	sd_host_controller sd_host_controller_u2(														
		.clk(clk),											// 										                  input 			
		.reset(reset),										//											   	            input
		.card_inserted_strb(card_inserted_strb),	//											                  input
		.card_removed_strb(card_removed_strb),		//											                  input
		                                                                              
		.rd_reg_index(rd_reg_index), 		         // which reg to read, input					         input    
		.rd_reg_output(rd_reg_output),	         // export reg data, output						         output
		.wr_reg_strb(wr_reg_strb),			         // strobe to write data, input				         input	
		.wr_reg_index(wr_reg_index),		         // which reg to write, input					         input 
		.wr_reg_input(wr_reg_output),		         // data to write, input							         input 
		.reg_attr(reg_attr),					         // input												         input 
		.kind_of_resp(kind_of_resp), 		         // based on command index, input				         input 
		                                                                                             
		.data(data),										// 																input						
																											   
		// For adma state machine.																	   		
		.strt_adma_strb(strt_adma_strb),	         // Start Fifo transfer to sd card. 			         input 
		.pkt_crc(pkt_crc),					         // CRC for the 512 bytes packet.				         input	
      .des_fifo_rd_strb(des_fifo_rd_strb),      // strobe for descriptor item                      output
      .des_rd_data(des_rd_data),                // descriptor item                                 input 
      .fin_cmnd_strb(fin_cmnd_strb),            // finished sending out cmd13, response is ready   input
																											
		// For Fifo data.																				
		//.strt_fifo_strb(strt_fifo_strb),	// Start Fifo transfer to sd card.		      output 	 
      // This signals fetches the first data word from the
      // data bram.
      .strt_snd_data_strb(strt_snd_data_strb),  // first set of data to sd card                    output
		// This signal fetches the consecutive data word from the                                    
      // data bram.                                                                                
   	.new_dat_strb(new_dat_strb),		         // Ready for next set of data to sd card           output	
		.sm_rd_data(sm_rd_data),			         // from the system memory RAM		 	 		         input   
		.fifo_rdy_strb(fifo_rdy_strb),            // fifo is ready to be used					         input	  
																											                  
		.end_bit_det_strb(end_bit_det_strb),      // finished sending out command			            output
		.r1_crc7_good_out(),						      // output											         output 
      .snd_auto_cmd12_strb(snd_auto_cmd12_strb),//                                                 output
      //.issue_abort_cmd(issue_abort_cmd)         //                                               output 
      .snd_cmd13_strb(snd_cmd13_strb),          // send cmd13 to poll for card ready               output 
                                                                                                      
		.D0_in(IO_SDC1_D0_in), 					      // only D0 has a busy signal				            input	
		.D0_out(IO_SDC1_D0_out),				      //													            output
		.D1_in(IO_SDC1_D1_in), 					      //													            input	
		.D1_out(IO_SDC1_D1_out),				      //													            output
		.D2_in(IO_SDC1_D2_in),	 				      //													            input	
		.D2_out(IO_SDC1_D2_out),				      //													            output
		.D3_in(IO_SDC1_D3_in),	 				      //													            input	
		.D3_out(IO_SDC1_D3_out),				      //													            output
		.SDC_CLK(IO_SDC1_CLK),					      //													            output
		.cmd_in(IO_SDC1_CMD_in),				      //													            input	
		.cmd_out(IO_SDC1_CMD_out)				      //													            output
	);																										
																											
endmodule																								
																											