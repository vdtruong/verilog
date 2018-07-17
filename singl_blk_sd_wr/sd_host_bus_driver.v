`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:17:57 10/05/2012 
// Design Name: 
// Module Name:    sd_host_bus_driver 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: The sd_host_bus_driver talks to the PUC directly. It is
//                      between the PUC and the sd_host_controller.  The 
//								sd_host_controller talks directly to the SD Card.
///////////////////////////////////////////////////////////////////////////////
module sd_host_bus_driver
#(parameter BRAM_SYSMEM_FILE 	= "C:/FPGA_Design/sd_card_controller/src/BRAM_66_x_64.txt",
  parameter SM_MEM_SIZE       = 128,
  parameter SM_ADDR_WD        = 7,
  parameter SM_DATA_WD        = 64)
 (
	input 					clk,
	input						reset,
	// Next three inputs for enable interrupts.
	input						enb_int_strb, 	// enable an interrupt from PUC
	input 		[11:0]	enb_addr, 		// memory map address
	input 		[15:0]	enb_data, 		// memory map data
	// card has been inserted and stabilized
	input						card_inserted_strb, 	
	// card has been removed and stabilized
	input						card_removed_strb, 	
	
	// manually initialize the sd card
	input						man_init_sdc_strb,		
	// test cmd strb from host (ie, CMD8)
	input						host_tst_cmd_strb,
	// finished sending out command to sd card
	input						end_bit_det_strb,	
	// read register from host controller from PUC
	input			[11:0]	rd_reg_indx_puc,
	// indicates manual write to host controller from PUC
	// Make sure to turn this off when not sending from puc.
	input						wr_reg_man, 
	// indicates manual write strobe to host controller from PUC
	input						wr_reg_strb_man,
	// indicates manual write index to host controller from PUC
	input			[11:0]	wr_reg_index_man, 
	// indicates manual write output to host controller from PUC
	input			[15:0]	wr_reg_output_man,
	// indicates manual reg attr to host controller from PUC
	input			[2:0]		reg_attr_man, 
	// puc (or other host) starts a data transfer
	input 					start_data_tf_strb,
	// strobe for each set of data from puc (or other host)
	input 					data_in_strb, 
	// last set of data from puc (or other host)
	input 					last_set_of_data_strb,
	input 		[35:0] 	date,  // date from puc
	// Data from puc (or other host) per strobe. 
	// Also, use for test cmd (ie, CMD8).	
	// For the first 16 bits, it will be the
	// Command Register (00Eh) data.
	input 		[35:0]	data,								 				
	
	// for the sd host controller memory map
	output		[11:0]	rd_reg_index,
	input 		[127:0]	rd_reg_input,															 
	
	output					wr_reg_strb,
	output		[11:0]	wr_reg_index,
	output 		[31:0]	wr_reg_output,
	output 		[2:0]		reg_attr,												  						
	output reg	[2:0]		kind_of_resp, 	// based on command index
	
	// Following is for System Memory FIFO.						 
	//input						strt_fifo_strb;	// start to create descriptor table
	input						wr_b_strb,			// write puc data to fifo, from puc.
	input 		[63:0] 	fifo_data,			// data to be logged, from puc.	 
	output reg           rdy_for_nxt_pkt,	// ready for next packet (fifo_data) from puc.
	output					fifo_rdy_strb,		// fifo is ready to be used
	// These ports are used by ADMA2 State Machine						 
	output					strt_adma_strb,	// Start Fifo transfer to sd card.
   input                strt_snd_data_strb,  // start to send data to sd card.  
	input						nxt_dat_strb,		// Next data from fifo.
	output 		[63:0]	sm_rd_data,			// from the system memory ram
	input 		[31:0] 	sdc_wr_addr,		// sd card write address. 		  
	output		[15:0]	pkt_crc,				// CRC for 512 bytes from PUC. 
	input 		[31:0] 	sdc_rd_addr,		// sd card rd address. 		 
	
	input						r1_crc7_good_out 	// from sdc_cmd_mod
   );
	 
	// Registers
	reg				host_tst_cmd_strb_z1;
	reg				host_tst_cmd_strb_z2;
	reg	[15:0]	tf_mode;
	reg	[15:0]	command;
   reg 				cmd_with_tf_compl_int;
	reg	[1:0]		command_type;
	reg				data_pres_select;
	reg				cmd_indx_chk_enb;
	reg				cmd_crc_chk_enb;
	reg	[1:0]		resp_type_select;
	reg				issue_cmd_when_busy;
	reg	[11:0]	tf_blk_size;
	reg	[15:0]	blk_count;				 
	//reg	[63:0]	fifo_data;									  
	reg	[63:0]	dat_in;		// holds fifo_data for shifting into crc calculator								  
	reg				calc_crc;	// flag to calculate CRC								  
	reg				calc_crc_z1;// delay
	reg				crc_in;		// crc input bit							
	reg	[63:0] 	datain;		// either data from puc or crc.
	// Next seven registers are for the host controller reg. map,
	// internal use.
	reg	[11:0]	rd_reg_index_int; // for this module own reading
	reg 	[11:0] 	rd_reg_index_reg;	// for this module own reading
	reg 	[11:0] 	rd_reg2_index_reg;// for this module own reading
	reg	[11:0]	rd_reg_indx;		// to assign to output
	reg				wr_reg_strb_reg;
	reg	[11:0]	wr_reg_index_reg;
	reg	[31:0]	wr_reg_output_reg;
	reg	[2:0]		reg_attr_reg;
	
	reg	[5:0]		cmd_index;
	reg	[31:0] 	argument;     
	reg				card_insrtd_reg;
	reg				card_insrtd_reg_z1;
	reg				calc_clk_strb;			 
	reg	[23:0]	req_clk;
	reg	[23:0]	req_clk_sl; 			// for sensitivity list
	reg				just_insrtd;
	reg				just_insrtd_sl;		// for sensitivity list
	reg				init_suc; 				// card sucessfully initialized
	reg				init_not_suc; 			// card not sucessfully initialized
	reg				strt_clk_sup;  		// start clock supply after initializing
	reg				strt_clk_sup_z1;
   reg            strt_snd_data_strb_z1;
	reg				nxt_dat_strb_z1;													  
	reg				wr_b_strb_z1;			// delay									  
	reg				wr_b_strb_z2;			// delay											  
	reg				rst_crc_calc;			// reset the CRC calculator 
	reg				str_crc_strb_z1;		// delay							 
	reg				str_crc_strb_z2;		// delay							 
	reg				str_crc_strb_z3;		// delay
	reg		      fin_crc_calc_strb_reg;
	reg		      fin_crc_calc_strb_reg_z1;
	reg		      fin_crc_calc_strb_reg_z2;
   reg            stop_recv_pkt;
	
	// Wires
	wire	[SM_ADDR_WD-1:0]	sm_rd_addr; // read system memory addr
	wire	[SM_ADDR_WD	-1:0]	sm_wr_addr; // write system memory addr
  	//wire 	[SM_ADDR_WD-1:0] 	buffer_cnt;	// how much is in buffer	
	wire							wr_ram_enb; 	// for the system memory ram
	wire 	[7:0] 				wr_ram_addr;	// for the system memory ram
	wire 	[71:0]/*[511:0]*/	wr_ram_data;	// for the system memory ram
	wire							wr_ram_data_strb;
	//wire				issue_sd_cmd_strb;
	wire							issue_abort_cmd;		
	// From data_tf_using_adma
	wire							dtf_iss_sd_cmd_strb;
	
	//wire	[1:0]		gen4ClksCnt;
	wire							rd_2nd_input_strb;
	
	// For host controller memory map
	wire	[11:0]	rd_reg_index_sdc_det;
	wire	[11:0]	rd_reg_index_sup_clk;
	wire	[11:0]	rd_reg_index_clk_stop;
	wire	[11:0]	rd_reg_index_card_init;
	wire	[11:0]	rd_reg_index_iss;		// for issue_sd_cmd
	wire	[11:0]	rd_reg_index_fin;		// for fin_a_cmnd
	wire	[11:0]	rd_reg_index_data_tf;
	wire				wr_reg_strb_enb_int;
	wire				wr_reg_strb_sdc_det; 
	wire				wr_reg_strb_sup_clk; 
	wire				wr_reg_strb_clk_stop; 
	wire				wr_reg_strb_card_init; 	
	wire				wr_reg_strb_iss;  	// for issue_sd_cmd
	wire				wr_reg_strb_fin;  	// for fin_a_cmnd
	wire				wr_reg_strb_data_tf;
	wire	[11:0]	wr_reg_index_enb_int;
	wire	[11:0]	wr_reg_index_sdc_det;
	wire	[11:0]	wr_reg_index_sup_clk;
	wire	[11:0]	wr_reg_index_clk_stop;
	wire	[11:0]	wr_reg_index_card_init;
	wire	[11:0]	wr_reg_index_iss;		// for issue_sd_cmd
	wire	[11:0]	wr_reg_index_fin;		// for fin_a_cmnd
	wire	[11:0]	wr_reg_index_data_tf;
	wire 	[31:0]	wr_reg_output_enb_int;
	wire 	[31:0]	wr_reg_output_sdc_det;
	wire 	[31:0]	wr_reg_output_sup_clk;
	wire 	[31:0]	wr_reg_output_clk_stop;
	wire 	[31:0]	wr_reg_output_card_init;
	wire 	[31:0]	wr_reg_output_iss;	// for issue_sd_cmd
	wire 	[31:0]	wr_reg_output_fin;	// for fin_a_cmnd
	wire 	[31:0]	wr_reg_output_data_tf;
	wire 	[2:0]		reg_attr_enb_int;
	wire 	[2:0]		reg_attr_sdc_det;
	wire 	[2:0]		reg_attr_sup_clk;
	wire 	[2:0]		reg_attr_clk_stop;
	wire 	[2:0]		reg_attr_card_init;
	wire 	[2:0]		reg_attr_iss;			// for issue_sd_cmd
	wire 	[2:0]		reg_attr_fin;			// for fin_a_cmnd
	wire 	[2:0]		reg_attr_data_tf;
	
	// indicates that enb_interupt.v is being used.
	wire				enb_int_proc;
	// indicates that sdc_detection.v is being used.
	wire				sdc_det;
	// indicates that sd_clk_sup.v is being used.
	wire				sd_clk_proc;
	// indicates that sd_clk_stop.v is being used.
	wire				sd_clk_stop_proc;
	// indicates that card_init_and_id.v is being used.
	wire				card_init_proc;
	// indicates that issue_sd_cmd.v is being used.
	wire				iss_sd_cmd_proc;
	// indicates that fin_a_cmnd.v is being used.
	wire				fin_a_cmd_proc;
	wire				fin_a_cmd_strb; // ready to go to fin_a_cmnd module
	// indicates that data_tf_using_adma.v is being used.
	wire				dat_tf_adma_proc;
	
	// detected that card has been inserted or removed.
	wire				card_inserted; 	
	wire				sd_clk_enb_strb;	// sd clock is ready to be used.
	//wire				sd_clk_off_suc;	// will sucessfully turned off the sd clock
	wire				stby_strb;			// card is initialized sucessfully
	wire				not_int_strb;     // card is not initialized sucessfully
	wire	[15:0]	rca;													  
	wire				fin_stp_clk;								
	wire				dat_tf_mode;								
	wire				fin_crc_calc_strb;// finished calculating crc for one packet (64 bits).					
	wire				str_crc_strb;		// strobe to store crc in the fifo
	
	//Initialize sequential logic
	initial	
	begin
		rd_reg_index_int			   <= 12'h000;
		rd_reg_index_reg			   <= 12'h000;
		rd_reg2_index_reg			   <= 12'h000;
		rd_reg_indx					   <= 12'h000;
		wr_reg_strb_reg			   <= 1'b0;
		wr_reg_index_reg			   <= 12'h000;
		wr_reg_output_reg			   <= {32{1'b0}};
		reg_attr_reg				   <= 3'h0;
		                           
		cmd_index					   <= {6{1'b0}};
		argument						   <= {32{1'b0}};
									      
		dat_in						   <= {64{1'b0}};
		datain						   <= {64{1'b0}};
		calc_crc						   <= 1'b0;
		calc_crc_z1					   <= 1'b0;
		crc_in						   <= 1'b0;	
		wr_b_strb_z1				   <= 1'b0;	
		wr_b_strb_z2				   <= 1'b0;    		  
	   strt_snd_data_strb_z1	   <= 1'b0;		  
		nxt_dat_strb_z1			   <= 1'b0;
										   				  
		host_tst_cmd_strb_z1		   <= 1'b0;		  
		host_tst_cmd_strb_z2		   <= 1'b0;
		tf_mode						   <= {16{1'b0}};
		command						   <= {16{1'b0}};
		cmd_with_tf_compl_int	   <= 1'b0;
		command_type				   <= {2{1'b0}};
		data_pres_select			   <= 1'b0;
		cmd_indx_chk_enb			   <= 1'b0;
		cmd_crc_chk_enb			   <= 1'b0;
		resp_type_select			   <= {2{1'b0}};
		issue_cmd_when_busy		   <= 1'b0;
		tf_blk_size					   <= {12{1'b0}};
		blk_count					   <= {16{1'b0}};
		card_insrtd_reg			   <= 1'b0;
		card_insrtd_reg_z1		   <= 1'b0;
		calc_clk_strb				   <= 1'b0;	
		req_clk						   <= 24'h061A80; // 400 kHz
		req_clk_sl					   <= 24'h061A80; // 400 kHz
		just_insrtd					   <= 1'b0;
		just_insrtd_sl				   <= 1'b0;
		init_suc						   <= 1'b0; 		// card sucessfully initialized
		init_not_suc				   <= 1'b0; 		// card not sucessfully initialized
		strt_clk_sup				   <= 1'b0;  		// start clock supply after initializing
		strt_clk_sup_z1			   <= 1'b0;																 
		rst_crc_calc				   <= 1'b0;																 
		str_crc_strb_z1			   <= 1'b0;																 
		str_crc_strb_z2			   <= 1'b0;																 
		str_crc_strb_z3			   <= 1'b0;
      fin_crc_calc_strb_reg      <= 1'b0;
      fin_crc_calc_strb_reg_z1   <= 1'b0;
      fin_crc_calc_strb_reg_z2   <= 1'b0;
      stop_recv_pkt              <= 1'b0;
	end
	
	// Assign registers to outputs.
   assign wr_reg_strb     = wr_reg_strb_reg;
   assign wr_reg_index    = wr_reg_index_reg;
   assign wr_reg_output   = wr_reg_output_reg;
   assign reg_attr        = reg_attr_reg;
	assign rd_reg_index	  = rd_reg_indx;
	assign fifo_rdy_strb	  = str_crc_strb_z3; 
	                               
	// Set up delays
	always@(posedge clk)
	begin
		if (reset) begin
			card_insrtd_reg			   <= 1'b0;
			card_insrtd_reg_z1			<= 1'b0;  
			host_tst_cmd_strb_z1			<= 1'b0;	  
			host_tst_cmd_strb_z2			<= 1'b0;	  
			strt_snd_data_strb_z1		<= 1'b0;	  
			nxt_dat_strb_z1				<= 1'b0;	  
			wr_b_strb_z1					<= 1'b0;	  
			wr_b_strb_z2					<= 1'b0;														 
			str_crc_strb_z1				<= 1'b0;														 
			str_crc_strb_z2				<= 1'b0;														 
			str_crc_strb_z3			   <= 1'b0;
         fin_crc_calc_strb_reg_z1   <= 1'b0;
         fin_crc_calc_strb_reg_z2   <= 1'b0;
			calc_crc_z1					   <= 1'b0;
		end
		else begin
			card_insrtd_reg		      <= card_inserted;	
			card_insrtd_reg_z1		   <= card_insrtd_reg;	  	
			host_tst_cmd_strb_z1			<= host_tst_cmd_strb;	  
			host_tst_cmd_strb_z2			<= host_tst_cmd_strb_z1;	  
			strt_snd_data_strb_z1		<= strt_snd_data_strb;	  
			nxt_dat_strb_z1			   <= nxt_dat_strb;		  
			wr_b_strb_z1				   <= wr_b_strb;			  
			wr_b_strb_z2					<= wr_b_strb_z1;													 
			str_crc_strb_z1				<= str_crc_strb;													 
			str_crc_strb_z2				<= str_crc_strb_z1;												 
			str_crc_strb_z3			   <= str_crc_strb_z2;
         fin_crc_calc_strb_reg_z1   <= fin_crc_calc_strb_reg;
         fin_crc_calc_strb_reg_z2   <= fin_crc_calc_strb_reg_z1;
			calc_crc_z1					   <= calc_crc;
		end	
	end	
	
	// Switch rd_reg_indx_puc to rd_reg_index_reg.
	always@(posedge clk)
	begin
		if (reset)
			rd_reg_index_reg	<= 12'h000; 		
		else 
			rd_reg_index_reg	<= rd_reg_indx_puc;
	end		
	
	// Decide which rd_reg_index to use internal to this module.
	always@(posedge clk)
	begin
		if (reset) 
			rd_reg_index_int	<= 12'h000;
			// only when reading the second input
		else if (rd_2nd_input_strb)
			rd_reg_index_int	<= rd_reg2_index_reg;
		else 
			rd_reg_index_int	<= rd_reg_index_reg;
	end		
	
	// Becareful when you read and write two registers
	// at a time.  This is because all the strobes
	// and indexes are delayed by one clock.  You
	// may read and write with the same map register
	// and this could overlap.  Check the simulation.
	// Decide which rd_reg_indx to select.
	always@(posedge clk)
	begin
		if (reset) 
			rd_reg_indx	<= 12'h010;
		else if (sdc_det)
			rd_reg_indx	<= rd_reg_index_sdc_det;
		else if (sd_clk_proc)
			rd_reg_indx	<= rd_reg_index_sup_clk;
		else if (sd_clk_stop_proc) 
			rd_reg_indx	<= rd_reg_index_clk_stop; 
		else if (card_init_proc)
			rd_reg_indx	<= rd_reg_index_card_init;
		else if (iss_sd_cmd_proc)
			rd_reg_indx	<= rd_reg_index_iss;
		else if (fin_a_cmd_proc)
			rd_reg_indx	<= rd_reg_index_fin;
		else if (dat_tf_adma_proc)
			rd_reg_indx	<= rd_reg_index_data_tf;
		else 
			rd_reg_indx	<= rd_reg_index_int;	// default for internals
	end				 						  				 
	
	// Decide which wr_reg_strb_reg to select.
	always@(posedge clk)
	begin
		if (reset) 
			wr_reg_strb_reg	<= 1'b0;
		else if (wr_reg_man)
			wr_reg_strb_reg	<= wr_reg_strb_man;
		else if (enb_int_proc) 
			wr_reg_strb_reg	<= wr_reg_strb_enb_int;
		else if (sdc_det)
			wr_reg_strb_reg	<= wr_reg_strb_sdc_det;
		else if (sd_clk_proc)
			wr_reg_strb_reg	<= wr_reg_strb_sup_clk;	
		else if (sd_clk_stop_proc)
			wr_reg_strb_reg	<= wr_reg_strb_clk_stop;
		else if (card_init_proc) 
			wr_reg_strb_reg	<= wr_reg_strb_card_init; 
		else if (iss_sd_cmd_proc) 
			wr_reg_strb_reg	<= wr_reg_strb_iss;
		else if (fin_a_cmd_proc) 
			wr_reg_strb_reg	<= wr_reg_strb_fin;
		else if (dat_tf_adma_proc)
			wr_reg_strb_reg	<= wr_reg_strb_data_tf;
		else
			wr_reg_strb_reg	<= wr_reg_strb_reg;
	end
	
	// Decide which wr_reg_index_reg to select.
	always@(posedge clk)
	begin
		if (reset) 
			wr_reg_index_reg	<= 12'h000;
		else if (wr_reg_man)
			wr_reg_index_reg	<= wr_reg_index_man;
		else if (enb_int_proc)
			wr_reg_index_reg	<= wr_reg_index_enb_int;
		else if (sdc_det) 
			wr_reg_index_reg	<= wr_reg_index_sdc_det;
		else if (sd_clk_proc) 
			wr_reg_index_reg	<= wr_reg_index_sup_clk; 
		else if (sd_clk_stop_proc)
			wr_reg_index_reg	<= wr_reg_index_clk_stop; 
		else if (card_init_proc)
			wr_reg_index_reg	<= wr_reg_index_card_init;
		else if (iss_sd_cmd_proc) 
			wr_reg_index_reg	<= wr_reg_index_iss;
		else if (fin_a_cmd_proc)
			wr_reg_index_reg	<= wr_reg_index_fin;	
		else if (dat_tf_adma_proc) 
			wr_reg_index_reg	<= wr_reg_index_data_tf;
		else 
			wr_reg_index_reg	<= wr_reg_index_reg;
	end
	
	// Decide which wr_reg_output_reg to select.
	always@(posedge clk)
	begin
		if (reset) 
			wr_reg_output_reg	<= 32'h00000000;
		else if (wr_reg_man)
			wr_reg_output_reg	<= {16'h0000,wr_reg_output_man};
		else if (enb_int_proc)
			wr_reg_output_reg	<= wr_reg_output_enb_int;
		else if (sdc_det) 
			wr_reg_output_reg	<= wr_reg_output_sdc_det;
		else if (sd_clk_proc) 
			wr_reg_output_reg	<= wr_reg_output_sup_clk; 
		else if (sd_clk_stop_proc)
			wr_reg_output_reg	<= wr_reg_output_clk_stop;
		else if (card_init_proc)
			wr_reg_output_reg	<= wr_reg_output_card_init;
		else if (iss_sd_cmd_proc)
			wr_reg_output_reg	<= wr_reg_output_iss;
		else if (fin_a_cmd_proc)
			wr_reg_output_reg	<= wr_reg_output_fin;
		else if (dat_tf_adma_proc) 
			wr_reg_output_reg	<= wr_reg_output_data_tf; 
		else
			wr_reg_output_reg	<= wr_reg_output_reg;
	end
	
	// Decide which reg_attr_reg to select.
	always@(posedge clk)
	begin
		if (reset)
			reg_attr_reg	<= 3'h0; 	
		else if (wr_reg_man)
			reg_attr_reg	<= reg_attr_man;
		else if (enb_int_proc) 
			reg_attr_reg	<= reg_attr_enb_int;
		else if (sdc_det) 
			reg_attr_reg	<= reg_attr_sdc_det;
		else if (sd_clk_proc) 
			reg_attr_reg	<= reg_attr_sup_clk;	
		else if (sd_clk_stop_proc)
			reg_attr_reg	<= reg_attr_clk_stop;
		else if (card_init_proc) 
			reg_attr_reg	<= reg_attr_card_init;
		else if (iss_sd_cmd_proc)
			reg_attr_reg	<= reg_attr_iss;
		else if (fin_a_cmd_proc) 
			reg_attr_reg	<= reg_attr_fin;
		else if (dat_tf_adma_proc) 
			reg_attr_reg	<= reg_attr_data_tf;
		else 
			reg_attr_reg	<= reg_attr_reg;
	end
	
	// Create a strobe when we get a pos edge
	// trigger when the card  is inserted or
	// when we will sucessfully turned off the
	// sd clock.  This is so we can switch to
	// a different clock rate.
	always@(posedge clk)
	begin
		if (reset)
			calc_clk_strb			<= 1'b0;
				// posedge trigger, card inserted or after suc. initialization
		else if ((card_insrtd_reg && (!card_insrtd_reg_z1)) | 
					(strt_clk_sup && (!strt_clk_sup_z1)))  
			calc_clk_strb			<= 1'b1;	
		else 
			calc_clk_strb			<= 1'b0;
	end	
	
	// Decide if the card was just inserted.
//	always@(posedge clk)
//	begin
//		if (reset) begin
//			just_insrtd					<= 1'b0;
//		end		// posedge trigger, card inserted
//		else if (card_insrtd_reg && !card_insrtd_reg_z1) begin 
//			just_insrtd					<= 1'b1;
//		end	
//		else beginsd_clk_enb_strb
//			just_insrtd					<= 1'b0;
//		end
//	end	
	
	// Decide which clock frequency to use.
	// If we have just inserted the card, use 400 kHz.
	// If we have just entered the standby state, use higher.
//	always@(posedge clk)
//	begin
//		if (reset) begin
//			req_clk			<= 24'h061A80;
//		end		// posedge trigger, card inserted
//		else if ((card_insrtd_reg && !card_insrtd_reg_z1) | 
//					(sd_clk_off_suc_reg && !sd_clk_off_suc_reg_z1)) begin 
//			req_clk			<= 24'h061A80;
//		end	
//		else begin
//			req_clk			<= 24'h1E8480;
//		end
//	end
	
	// Keep track of req_clk.
	always@(posedge clk)
	begin
		if (reset)
			req_clk_sl  <= 24'h061A80;
		else
			req_clk_sl  <= req_clk;
	end 
	
	// Keep track of just_insrtd.
	always@(posedge clk)
	begin
		if (reset)
			just_insrtd_sl  <= 1'b0;
		else
			just_insrtd_sl  <= just_insrtd;
	end 
	
	// Flag if the card was sucessfully initialized.
	always@(posedge clk)
	begin
		if (reset)
			init_suc  <= 1'b0;
		else if (stby_strb) 
			init_suc  <= 1'b1;
		else 
			init_suc  <= init_suc;
	end 
	
	// Flag if the card was not sucessfully initialized.
	always@(posedge clk)
	begin
		if (reset)
			init_not_suc  <= 1'b0;
		else if (not_int_strb) 
			init_not_suc  <= 1'b1;
		else 
			init_not_suc  <= init_not_suc;
	end 
	
	// Use this module when you want to enable an interrupt.
	enb_interupt enb_interupt_u1 (
		 .clk(clk), 
		 .reset(reset), 
		 .enb_int_strb(enb_int_strb), // don't forget to set up these regs.
		 .enb_addr(enb_addr), 
		 .enb_data(enb_data),
		 
		 // For the Host Controller memory map
		 .wr_reg_strb(wr_reg_strb_enb_int), 
		 .wr_reg_index(wr_reg_index_enb_int), 
		 .wr_reg_output(wr_reg_output_enb_int),
		 .reg_attr(reg_attr_enb_int),
		 
		 .enb_int_proc(enb_int_proc)
		 );
	
	// This is when the SD Card is detected.
	// Either insertion or removal.
	// The sdc controller will take care of the
	// card insert and removal routines.  It will
	// then strobe this module for further action.
	sdc_detection sdc_detection_u2(
		.clk(clk),
		.reset(reset),
		// card has been inserted and stabilized from the host controller
		.card_inserted_strb(card_inserted_strb),
		// card has been removed and stabilized from the host controller
		.card_removed_strb(card_removed_strb),
		
		// For the Host Controller memory map
		.rd_reg_index(rd_reg_index_sdc_det),
		.rd_reg_input(rd_reg_input),
		.wr_reg_strb(wr_reg_strb_sdc_det),
		.wr_reg_index(wr_reg_index_sdc_det),
		.wr_reg_output(wr_reg_output_sdc_det),
		.reg_attr(reg_attr_sdc_det),
		
		.card_inserted(card_inserted), // the card has been inserted or removed
		.sdc_det(sdc_det)
   );
	 
	// Supply the SD Clock for other modules and the
	// SD Card.
	sd_clk_sup sd_clk_sup_u3 (
		.clk(clk), 
		.reset(reset), 
		.calc_clk_strb(calc_clk_strb | fin_stp_clk),
		// if the card has just been inserted, use 400 kHz
		// if we just entered stand by state, use higher frequency
		.req_clk(req_clk),
		// Assume 390 kHz before initialization.
		.dat_tf_mode(1'b1),
		
		// For the Host Controller memory map
		.rd_reg_index(rd_reg_index_sup_clk), 
		.rd_reg_input(rd_reg_input), 
		.wr_reg_strb(wr_reg_strb_sup_clk), 
		.wr_reg_index(wr_reg_index_sup_clk), 
		.wr_reg_output(wr_reg_output_sup_clk), 
		.reg_attr(reg_attr_sup_clk),
		 
		.sd_clk_enb_strb(sd_clk_enb_strb), // sd clock is ready
		.sd_clk_proc(sd_clk_proc)
    );
	 
	// Stop the sd clock when necessary.
	sd_clk_stop sd_clk_stop_u4 (
		.clk(clk), 
		.reset(reset), 
		// stop the sd clock when we first entered the
		// sd card standby state so we can change the
		// clock frequency.  Also, stop the clock when
		// we have removed the card.
		.stop_sd_clk_strb(stby_strb /*| not_int_strb*/),
		 
		// For the Host Controller memory map 
		.rd_reg_index(rd_reg_index_clk_stop), 
		.rd_reg_input(rd_reg_input), 
		.wr_reg_strb(wr_reg_strb_clk_stop), 
		.wr_reg_index(wr_reg_index_clk_stop), 
		.wr_reg_output(wr_reg_output_clk_stop), 
		.reg_attr(reg_attr_clk_stop),
		 
		.sd_clk_off_suc(/*sd_clk_off_suc*/), // will be stopped
		.fin_stp_clk(fin_stp_clk),
		.sd_clk_stop_proc(sd_clk_stop_proc)//sd_clk_stop_proc)
		);
	 
	// When the sd clock is ready, we'll start this
	// module.  May need to write code to indicate
	// that other commands may be able to start after
	// the card is initialized.
	card_init_and_id card_init_and_id_u5 (
		.clk(clk), 
		.reset(reset), 
		// make sure it doesn't initialize again
		// every time we change the clock speed.
		.start_strb(/*sd_clk_enb_strb || */man_init_sdc_strb), 
		.end_bit_det_strb(end_bit_det_strb),	// finished sending out command
		 
		// for host controller memory map
		.rd_reg_index(rd_reg_index_card_init), 
		.rd_reg_input(rd_reg_input), 
		.wr_reg_strb(wr_reg_strb_card_init), 
		.wr_reg_index(wr_reg_index_card_init), 
		.wr_reg_output(wr_reg_output_card_init), 
		.reg_attr(reg_attr_card_init),
	
		// card in stand by state, can change speed.
		// happens one clock before this process ends.
		// when the card has entered standby mode, we can
		// change the speed to something faster after 
		// initialization.
		.stby_strb(stby_strb), 
		.not_int_strb(not_int_strb),
		.cid_out(),						 
		.rca(rca),
		.card_init_proc(card_init_proc)
		);							

	// Pull out cmd_index from data.
	always @(posedge clk)
		begin
			if(reset)					 			  
				cmd_index	<= {6{1'b0}};
			else								 					 
				cmd_index	<= data[13:8];
		end
		
	// Pull out command_type from data.
	always @(posedge clk)
		begin
			if(reset)					 			  
				command_type	<= {2{1'b0}};
			else								 					 
				command_type	<= data[7:6];
		end		
		
	// Pull out data_pres_select from data.
	always @(posedge clk)
		begin
			if(reset)					 			  
				data_pres_select	<= 1'b0;
			else								 					 
				data_pres_select	<= data[5];
		end
		
	// Pull out cmd_indx_chk_enb from data.
	always @(posedge clk)
		begin
			if(reset)					 			  
				cmd_indx_chk_enb	<= 1'b0;
			else								 					 
				cmd_indx_chk_enb	<= data[4];
		end
		
	// Pull out cmd_crc_chk_enb from data.
	always @(posedge clk)
		begin
			if(reset)					 			  
				cmd_crc_chk_enb	<= 1'b0;
			else								 					 
				cmd_crc_chk_enb	<= data[3];
		end
		
	// Pull out resp_type_select from data.
	always @(posedge clk)
		begin
			if(reset)					 			  
				resp_type_select	<= {2{1'b0}};
			else								 					 
				resp_type_select	<= data[1:0];
		end									

	// For manual command only.
	// Automated processes will have its
	// agrgument determined.
	always @(posedge clk)
		begin
			if (reset)					 			 	  				   							 
				argument	<= {32{1'b0}};					
			else if (cmd_index == 8'h07)  // sel_desel_card										 
				argument	<= {rca,{16{1'b0}}};
			else if (cmd_index == 8'h08)  // send_if_cond										 
				argument	<= {{20{1'b0}},4'h1,8'hAA};		
			else if (cmd_index == 8'h0D)  // send_status  										 
				argument	<= {rca,{16{1'b0}}};
			else if (cmd_index == 8'h11)  // read_single_block
				// Address to be read.
				argument	<= sdc_rd_addr;					
			else if (cmd_index == 8'h18)	// write_block
				// Address to write.
				argument	<= sdc_wr_addr;
			// This is to start the initialization with command acmd41.
			else if (cmd_index == 8'h29 && (data[31:16] != 0))  										 
				argument	<= {1'b0,1'b1,{6{1'b0}},data[31:16],{8{1'b0}}};
			else  										 
				argument	<= {32{1'b0}};
		end
							
	// Combinational output for kind_of_resp, see page 71
	// of Physical Layer Simplified Specification Version 3.01.
	// Remember, if cmd_index doesn't change
	// kind_of_resp does not change.
	always @(cmd_index)
		begin
			case(cmd_index)						
				8'h02: begin								 							 
							kind_of_resp	= 3'h3;//3'h2;
				end	
				8'h03: begin								 							 
							kind_of_resp	= 3'h7;//3'h6;
				end													
				8'h07: begin								 							 
							kind_of_resp	= 3'h1;
				end														  
				8'h08: begin								 							 
							kind_of_resp	= 3'h0;//3'h7;
				end							
				default: begin							  				   							 
							kind_of_resp	= 3'h0;
				end
			endcase
		end
	
	// The two modules below take care of all the communication
	// with the host controller.  The host controller than
	// communicates with the sd card.
	// For command without data.
	issue_sd_cmd issue_sd_cmd_u6 (
		.clk(clk), 
		.reset(reset), 			
		// wait two clocks so we have time to parse out the
		// necessary information from data input from the host.
		.issue_sd_cmd_strb(host_tst_cmd_strb_z2 || dtf_iss_sd_cmd_strb), 
		.cmd_index(cmd_index), 					// See 2.2.6 Command Reg. (00Eh)
		.argument(argument), 
		.command_type(command_type), 			// See 2.2.6 Command Reg. (00Eh) 
		.data_pres_select(data_pres_select),// See 2.2.6 Command Reg. (00Eh) 
		.cmd_indx_chk_enb(cmd_indx_chk_enb),// See 2.2.6 Command Reg. (00Eh) 
		.cmd_crc_chk_enb(cmd_crc_chk_enb), 	// See 2.2.6 Command Reg. (00Eh)
		.resp_type_select(resp_type_select),// See 2.2.6 Command Reg. (00Eh)
		.issue_cmd_when_busy(issue_cmd_when_busy), 
		.issue_abort_cmd(issue_abort_cmd),
		// For the Host Controller memory map
		.rd_reg_index(rd_reg_index_iss), 
		.rd_reg_input(rd_reg_input), 
		// Need to determine which module is writing an output.
		.wr_reg_strb(wr_reg_strb_iss), 
		.wr_reg_index(wr_reg_index_iss), 
		.wr_reg_output(wr_reg_output_iss), 
		.reg_attr(reg_attr_iss),
		 
		.fin_a_cmd_strb(fin_a_cmd_strb),
		.iss_sd_cmd_proc(iss_sd_cmd_proc)
		);
		 
	// We use this module right after we use issue_sd_cmd.
	fin_a_cmnd fin_a_cmnd_u7 (
		.clk(clk), 
		.reset(reset), 
		.fin_a_cmd_strb(fin_a_cmd_strb), 
		.cmd_index(cmd_index), 
		.cmd_with_tf_compl_int(cmd_with_tf_compl_int), 	 
		.end_bit_det_strb(end_bit_det_strb),	// finished sending out command
		
		// For the Host Controller memory map
		.rd_reg_index(rd_reg_index_fin), 
		.rd_reg_input(rd_reg_input), 
		// Need to determine which module is writing the output.
		// Both can't share one wr_reg_xxx.
		.wr_reg_strb(wr_reg_strb_fin), 
		.wr_reg_index(wr_reg_index_fin), 
		.wr_reg_output(wr_reg_output_fin), 
		.reg_attr(reg_attr_fin), 

		//.resp_reg_data(), // from Response register (010h)
		.err_int_stat(/*err_stat*/), 
		.fin_a_cmd_proc(fin_a_cmd_proc),
		.fin_cmnd_strb(/*fin_cmnd_strb*/)
		);								  
	
	// This is for sending a command with data.
	data_tf_using_adma data_tf_using_adma_u8 (
		.clk(clk), 									                         //      input 
		.reset(reset), 															 // 		input
		// puc (or other host) starts a data transfer					 			     
		.start_data_tf_strb(start_data_tf_strb), 							 // 		input
		// strobe for each set of data from puc (or other host)		 			     
		.data_in_strb(data_in_strb), 											 // 		input
		// last set of data from puc (or other host)						 			     
		.last_set_of_data_strb(last_set_of_data_strb), 					 // 		input
		.date(date), 	// date from puc (or other host) per strobe	    		input
		.data(data),	// data from puc (or other host) per strobe 	 	 		input
		.tf_blk_size(tf_blk_size), 											 //		input
		.blk_count(16'h0001), 													 //		input
		.argument(sdc_wr_addr),	// Data Address 							 			input
		.tf_mode(16'h0001), 														 //      input
		.command(16'h1800),		// right now hard code for cmd24. 	 	      input
																						 	      
		// For the Host Controller memory map								 	
		.rd_reg_index(rd_reg_index_data_tf), 								 	//    output
		.rd_reg_input(rd_reg_input), 											 	//    input 
		.wr_reg_strb(wr_reg_strb_data_tf), 									 	//    output
		.wr_reg_index(wr_reg_index_data_tf), 								 	//    output
		.wr_reg_output(wr_reg_output_data_tf), 							 	//    output
		.reg_attr(reg_attr_data_tf),											 	//    output
		 																				 	      
		.issue_sd_cmd_strb(dtf_iss_sd_cmd_strb), 							 	//    output
		.issue_abort_cmd(issue_abort_cmd),									 	//    output
																						 	      
		// To save information to System Memory RAM.						 	
		.wr_ram_addr(wr_ram_addr), 											 	//    output
		.wr_ram_data(wr_ram_data), 											 	//    output
		.wr_ram_enb(wr_ram_enb), 												 	//    output      
																						 	
		.strt_adma_strb(strt_adma_strb),	// start the adma state machine		output
		.dat_tf_adma_proc(dat_tf_adma_proc)									 	//		output
		);														 
		
	// Decide which data to put into the Block RAM.
	always @(posedge clk)
		begin
			if(reset)					 			  
				datain	<= {64{1'b0}};
			else if (str_crc_strb_z1)		
				// We include the stop bit after the crc.
				datain	<= {pkt_crc,1'b1,{47{1'b1}}};  
			else				  
				datain	<= fifo_data;
		end									
	
	// This is the System Memory RAM.
	// It is for storing the data
	// to be used in ADMA2.										  
	// we only have one block (512 bytes) to write each time.
	// System Memory RAM (64x64, 64 items with 64 bits each).
   // We don't use index 0 of the system memory so we will
   // need 65 locations to store the date, 63 packets and the
   // CRC.
	// Need to know when to start saving data from PUC.
	// Do we start when we start the ADMA state machine or
	// before that? 
	// When the data comes over from the PUC, we store the data
	// in the fifo and also calculate the CRC for the whole word
   // as it comes in one at a time.
  	defparam BlockRAM_DPM_66_x_64_i.BRAM_DPM_INITIAL_FILE = BRAM_SYSMEM_FILE;  
  	BlockRAM_DPM_66_x_64  BlockRAM_DPM_66_x_64_i
  	(	
		.clk(clk), 										//						input 
      .addr_a(sm_rd_addr),							// for read       input 
      .datain_a(),    								//                input 
      .wr_a(),            							//                input 
      .addr_b(sm_wr_addr),    					// for writing    input 
      .wr_b(wr_b_strb_z2 || str_crc_strb_z2),//	               input 
      .datain_b(datain), 							//                input 
      .dataout_a(sm_rd_data),						//                output
      .dataout_b()									//                output
  	);   
	
  	defparam FifoCntrllr.WIDTH	= SM_ADDR_WD; 
	FifoController	FifoCntrllr					
	(
  		.clk(clk),     // System Clock	                                             input 	                                                                
  		.reset(reset || strt_adma_strb), // System Reset										input 
  		.enable(),     // Enable Fifo   																input 							 
  		.rd_a_strb((strt_snd_data_strb && !strt_snd_data_strb_z1)||(nxt_dat_strb && !nxt_dat_strb_z1)),// Read Strobe to empty	         input                       
  		.wr_b_strb(wr_b_strb || str_crc_strb_z1),		// Write Strobe to fill				input 							 
  		.addr_a(sm_rd_addr),   								// output address, read addr		output							 
  		.addr_b(sm_wr_addr),   								// input address, write addr		output							 
  		.fifo_empty(), // flag that fifo is empty													output							 
  		.fifo_full(),  // flag that fifo is full													output							 
 		.fifo_half() 	// flag that fifo is half full											output	
	);	 							 

	// Capture and Shift (left) the data, MSBit first.
	always@(posedge clk)
	begin
		if (reset) begin						  				 
			dat_in 			<= {64{1'b0}};
			crc_in			<= 1'b0;
		end
		else if (wr_b_strb)
			// new packet received
			dat_in 			<= fifo_data;	
		else if (calc_crc) begin 							 
			// shift and push if calc_crc is on
			dat_in[63:1]	<= dat_in[62:0];							  
			crc_in			<= dat_in[63];	// push msbit first;			  
		end												
		else
			crc_in 			<= 1'b0;
	end			
		
	// Reset the crc calculator when we have finished
	// sending the data.	 Actually, we can turn it off
	// earlier, check the timing diagram.
	always @(posedge clk)
		begin
			if(reset)					 			  
				rst_crc_calc	<= 1'b0;	
			else if (sm_rd_addr == 	8'h3E)							 					 
				rst_crc_calc	<= 1'b1;
			else								 					 
				rst_crc_calc	<= 1'b0;
		end			
	
	// Calculates the crc16 of one block of data.
	// One block is 512 bytes.  So we need to calculate 
	// the CRC for 64 packets of 64 bits.
	sd_crc_16 calcCRC0(
		.BITVAL(dat_in[63]),								// Next input bit
		// Enable it for two clocks.  First clock is for dat[4],
		// second clock is for dat[0].
    	.Enable(calc_crc),      	
		.CLK(clk),    										// Current bit valid (Clock)
		// Reset for new block (512 bytes) of data.
		// Need to find a condition to reset this CRC.
      .RST(rst_crc_calc),
		// Need to pass this CRC to the send module.
		// May need to strobe to get this crc so we have the correct one.
   	.CRC(pkt_crc)	
	); 											 
	
	//-------------------------------------------------------------------------
	// We need to calculate the CRC of each packet of data from the PUC.
	// Each packet is one item from the PUC, which has 64 bits.
	//-------------------------------------------------------------------------
	defparam calcCRCCntr_u11.dw 	= 7;
	// Change this to reflect the number of counts you want.
	defparam calcCRCCntr_u11.max	= 7'h3E;	// tweak to match the continuos crc
	//-------------------------------------------------------------------------
	CounterSeq calcCRCCntr_u11(
		.clk(clk), 						// Clock input 50 MHz 
		.reset(reset),	
		.enable(1'b1), 	
		.start_strb(wr_b_strb_z2),	// strobe to start calculation.  May want to wait one clock.
		.cntr(/*crc_calc_cnts*/), 
		.strb(fin_crc_calc_strb) 	// output
	);										
        
  	//---------------------------------------------------------------
	// Keep track of how many puc data words have came in.
	// When the time is up, we store the crc in the fifo.
  	//
  	defparam crcSetsCntr_u12.dw 	= 7;
  	defparam crcSetsCntr_u12.max 	= 7'h40;  
  	//---------------------------------------------------------------
  	Counter crcSetsCntr_u12
  	(
    	.clk(clk),
    	.reset(reset),
    	.enable(fin_crc_calc_strb),
    	.cntr(),
    	.strb(str_crc_strb)
  	);																									  
	
	// A register version of fin_crc_calc_strb.
   // We need this to create other flags.
	always@(posedge clk)
	begin
		if (reset) 
			fin_crc_calc_strb_reg <= 1'b0;
		else if (fin_crc_calc_strb) 
			fin_crc_calc_strb_reg <= 1'b1;			  
		else 
			fin_crc_calc_strb_reg <= 1'b0;
	end																								  
	
	// Stop receiving packets 
	always@(posedge clk)
	begin
		if (reset) 
			stop_recv_pkt <= 1'b0;
		else if (str_crc_strb) 
			stop_recv_pkt <= 1'b1;			  
		else if (strt_snd_data_strb)
			stop_recv_pkt <= 1'b0;
	end																								  
	
	// Ready for next packet from PUC.
	always@(posedge clk)
	begin
		if (reset) 
			rdy_for_nxt_pkt <= 1'b0;
		else if (!stop_recv_pkt && fin_crc_calc_strb_reg_z2) 
			rdy_for_nxt_pkt <= 1'b1;			  
		else
			rdy_for_nxt_pkt <= 1'b0;
	end																						  
	
	// Create a flag to allow shifting of the data for crc16 
	// calculation.  
	always@(posedge clk)
	begin
		if (reset) 
			calc_crc <= 1'b0;
		else if (wr_b_strb_z2) 
			calc_crc <= 1'b1;	
		// Also need to turn this off so we don't
		// have to shift it any more.
		else if (fin_crc_calc_strb) 
			calc_crc <= 1'b0;			  
		else 
			calc_crc <= calc_crc;
	end
	
	//-------------------------------------------------------------------------
	// We need a generic 4 clocks counter to get a second register read from
	// the map register.  We do this rather than have two read registers
	// from the host controller.
	//-------------------------------------------------------------------------
	defparam gen4ClksCntr_u10.dw 	= 2;
	// Change this to reflect the number of counts you want.
	defparam gen4ClksCntr_u10.max	= 2'h3;	
	//-------------------------------------------------------------------------
	CounterSeq gen4ClksCntr_u10(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		.start_strb(/*rd_input_strb*/1'b0), // strobe when read 1st input.
		.cntr(/*gen4ClksCnt*/), 
		.strb(rd_2nd_input_strb) // output
	);
	
	// Some steps we need to do when the card is inserted. //////
   parameter STE_STRT 		= 3'b000;
   parameter STE_SUP_CLK 	= 3'b001;
   parameter STE_INIT_CRD 	= 3'b010;
   parameter STE_STP_CLK 	= 3'b011;
//   parameter <state5> = 3'b100;
//   parameter <state6> = 3'b101;
//   parameter <state7> = 3'b110;
//   parameter <state8> = 3'b111;
	
	reg [2:0] 	pres_state = STE_STRT;
	reg [2:0]	next_state;
	
	//FSM register
	always @(posedge clk)
		begin
			if(reset)
				pres_state = STE_STRT;
			else
				pres_state = next_state;
		end 

	// FSM combinational block for next state
	always @(pres_state or card_insrtd_reg or card_insrtd_reg_z1 
				or just_insrtd or sd_clk_enb_strb or stby_strb
				or not_int_strb or card_init_proc or init_suc or init_not_suc
				or sd_clk_stop_proc)
		begin
			case (pres_state)
				STE_STRT: begin			// rising edge, card inserted
					if (card_insrtd_reg && !card_insrtd_reg_z1) begin 
						next_state 		= STE_SUP_CLK;
					end						// falling edge, card removed
					else if (!card_insrtd_reg && card_insrtd_reg_z1) begin 
						next_state 		= STE_STP_CLK;
					end
					else begin
						next_state 		= STE_STRT;
					end
				end
				STE_SUP_CLK: begin
					// was just inserted and sd clock is ready
					if (just_insrtd && sd_clk_enb_strb) begin	
						next_state 		= STE_INIT_CRD;
					end
					// has been inserted and sd clock is ready
					if (!just_insrtd && sd_clk_enb_strb) begin 
						next_state 		= STE_STRT;
					end
					else begin
						// make sure we stay here until the supply clock is ready
						next_state 		= STE_SUP_CLK; 
					end
				end
				STE_INIT_CRD: begin
					// We go to the stop clock state no matter if the card was
					// sucessfully initialized or not.  We have to turn off the clock
					// so we can change the frequency if it is sucessful, or leave it
					// off it is not sucessful.
					// if card was sucessfully initialized
					if (stby_strb && card_init_proc) begin
						next_state 		= STE_STP_CLK;
					end
					// if card was not sucessfully initialized
					else if (not_int_strb && card_init_proc) begin
						next_state 		= STE_STP_CLK;
					end	
					else begin
						// wait here til the card has gone through its initialization
						next_state 		= STE_INIT_CRD; 
					end
				end
				STE_STP_CLK: begin
					// if card was sucessfully initialized and after
					// the process is done.
					if (init_suc && !sd_clk_stop_proc) begin
						next_state 		= STE_SUP_CLK;
					end
					// if card was not sucessfully initialized and after 
					// the process is done.
					else if (init_not_suc && !sd_clk_stop_proc) begin
						next_state 		= STE_STRT;
					end	
					else begin
						// wait here til the clock has stopped
						next_state 		= STE_STP_CLK; 
					end
				end
				default: next_state 	= STE_STRT;
			endcase
		end // fsm
							
	// Moore output definition using pres_state
	always @(pres_state or card_insrtd_reg or card_insrtd_reg_z1 or req_clk_sl
				or just_insrtd_sl or init_suc or init_not_suc or sd_clk_stop_proc)
		begin
			case(pres_state)
				STE_STRT: begin		// rising edge
					if (card_insrtd_reg && !card_insrtd_reg_z1) begin  
						//calc_clk_strb		= 1'b1;  
						just_insrtd			= 1'b1;
					end
					else begin   
						just_insrtd			= 1'b0;
					end
					req_clk					= 24'h061A80;			
					strt_clk_sup 			= 1'b0;
				end
				STE_SUP_CLK: begin
						//calc_clk_strb		= 1'b0; // create a strobe
					just_insrtd				= just_insrtd_sl;
					req_clk					= req_clk_sl; 
					strt_clk_sup 			= 1'b0;
				end
				STE_INIT_CRD: begin
						//calc_clk_strb		= 1'b0; 
					just_insrtd				= just_insrtd_sl;
					req_clk					= req_clk_sl; 
					strt_clk_sup 			= 1'b0;
				end
				STE_STP_CLK: begin
					//calc_clk_strb		= 1'b0;
					just_insrtd				= just_insrtd_sl;
					req_clk					= 24'h1E8480; 
					// if card was sucessfully initialized and after
					// the process is done. 
					if (init_suc && !sd_clk_stop_proc) begin
						strt_clk_sup 		= 1'b1;
					end
					// if card was not sucessfully initialized and after 
					// the process is done.
					else if (init_not_suc && !sd_clk_stop_proc) begin
						strt_clk_sup 		= 1'b0;
					end
					else begin
						strt_clk_sup 		= 1'b0;
					end
				end
				default: begin
					//calc_clk_strb		= 1'b0; 
					just_insrtd				= just_insrtd_sl;
					req_clk					= req_clk_sl; 
					strt_clk_sup 			= 1'b0;
				end
			endcase
		end // outputs

endmodule
