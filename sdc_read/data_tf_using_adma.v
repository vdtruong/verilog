`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company:       V. Truong
// Engineer:      Fresenius NA
// 
// Create Date:   17:26:48 10/10/2012 
// Design Name: 
// Module Name:   data_tf_using_adma 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 	This module sends out a command with data going out or 
//						comming back.  3.7.2.3 Using ADMA, Figure 3-15, pg 115.
//
// Dependencies: 
//
// Revision: 07/25/2016
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module data_tf_using_adma(
   input 				clk,
   input 				reset,
	// puc (or other host) starts a data transfer
	input 				start_data_tf_strb,
	// strobe for each set of data from puc (or other host)
	input 				data_in_strb, 
	// last set of data from puc (or other host)
	input 				last_set_of_data_strb,
	input 	[35:0] 	date,                      // date from puc
	// data from puc (or other host) per strobe
	// We'll accept 36 bits of data at a time.
   // Not using it anywhere.
	//input 	[35:0] 	data, 
	input		[11:0]	tf_blk_size,
	input		[15:0]	blk_count,
	input		[31:0] 	argument,
	input		[15:0]	tf_mode,
	input		[4:0]	   des_rd_addr,               // descriptor table item														  
	
	// For Host Controller Register Map.
	output	[11:0]	rd_reg_index, 	            // for the sd host controller memory map 
	input 	[127:0]	rd_reg_input, 	            // from the sd host controller memory map
	output				wr_reg_strb, 	            // for the sd host controller memory map
	output	[11:0]	wr_reg_index, 	            // for the sd host controller memory map
	output 	[31:0]	wr_reg_output,             // for the sd host controller memory map
	output 	[2:0]		reg_attr,	
   output            wr_descr_table_strb,       // start descriptor table                                        
	
	output				issue_sd_cmd_strb,
	output				issue_abort_cmd,
	
	output	[7:0] 	wr_ram_addr,               // for the system memory ram	
	output 	[71:0]	wr_ram_data, 	            // for the system memory ram
	output			 	wr_ram_enb,		            // for the system memory ram
	
	output reg		   strt_fifo_strb,	         // start to save data into the fifo.
   input             fifo_rdy_strb,             // ready to start sending data out
	output reg			strt_adma_strb,	         // Start the ADMA state machine.
	output				dat_tf_adma_proc 	         // indicates that we are in this module
	);
	
	// Registers
	reg 	[7:0] 	wr_ram_addr_reg;        // for the system memory ram	
	reg 	[71:0]	wr_ram_data_reg; 	      // for the system memory ram
	reg				wr_ram_enb_reg;	      // for the system memory ram
	reg 	[63:0]	descr_table;
	reg				wr_descr_table_strb_reg;
	reg				wr_ram_data_strb;
	reg				data_in_strb_z1;
	reg				data_in_strb_z2;
	reg	[7:0]		descr_addr;
	reg	[7:0]		data_addr;
	reg	[1:0]		attr_act;
	reg				attr_dma_int;
	reg				attr_end_descr;
	reg				attr_valid;
	reg 				wr_reg_strb_reg; 		   // for the sd host controller memory map
	reg 	[11:0] 	wr_reg_index_reg; 	   // for the sd host controller memory map
	reg 	[31:0]	wr_reg_output_reg; 	   // for the sd host controller memory map
	reg 				cmd_complete;
	reg 				tf_complete;
   reg   [15:0]	command;
	
	reg	[11:0]	rd_reg_index_int; 	      // for this module own reading
	// indicates we are reading the 1st reg, then 2nd.
	reg				rd_input_strb;
	reg 	[11:0] 	rd_reg_index_reg; 	      // for the sd host controller memory map 
	reg 	[2:0]		reg_attr_reg; 
	reg				adma_err_int;
	reg				issue_sd_cmd_strb_reg;	   // issue a command without data
	reg				issue_abort_cmd_reg;		 
	reg				rdy_for_dat;				   // Card status is ready for data (cmd17).
	reg				dat_tf_adma_proc_reg;
   reg            normal_int_stat_bit_1;     // bit 1 for transfer complete
	reg            normal_int_stat_bit_1_z1;  // delay version
	// Wires
   wire 	[71:0]	output_data;
	wire				rd_2nd_input_strb;
	wire				read_clks_tout;         // finished reading register from host controller
	// Get out of waiting if has not received a response from a cmnd.
	wire				rd_to_strb;	    
	
	// Initialize sequential logic
	initial			
	begin
		// this could vary between desc table or data
		wr_ram_addr_reg 			      <= 8'h00; 
		// this could vary between desc table or data
		wr_ram_data_reg 		         <= {72{1'b0}};	
		wr_descr_table_strb_reg	      <= 1'b0;
		wr_ram_data_strb			      <= 1'b0;
		data_in_strb_z1			      <= 1'b0;
		data_in_strb_z2			      <= 1'b0;
		descr_addr					      <= 8'h00; // starts off with this
		data_addr					      <= 8'h08; // starts off with this
		// we'll default for transfer data for now
		attr_act						      <= 2'b10;
		// we'll default it to interrupt for now
		attr_dma_int				      <= 1'b1; 
		attr_end_descr				      <= 1'b0;
		// we'll default it to valid for now
		attr_valid					      <= 1'b0; 
		wr_reg_index_reg			      <= 12'h000;
		wr_reg_output_reg			      <= 32'h00000000;
		cmd_complete				      <= 1'b0;
		tf_complete					      <= 1'b0;
		wr_reg_strb_reg			      <= 1'b0;      
		command 		                  <= {16{1'b0}};
		                              
		rd_reg_index_int			      <= 12'h000;
		rd_input_strb				      <= 1'b0;
		rd_reg_index_reg			      <= 12'h000;   
		reg_attr_reg				      <= 3'h0;
		adma_err_int				      <= 1'b0;
		issue_sd_cmd_strb_reg	      <= 1'b0;
		issue_abort_cmd_reg		      <= 1'b0;
		strt_fifo_strb				      <= 1'b0;
		strt_adma_strb				      <= 1'b0;	  
		rdy_for_dat					      <= 1'b0;
		dat_tf_adma_proc_reg		      <= 1'b0;
		normal_int_stat_bit_1		   <= 1'b0;
		normal_int_stat_bit_1_z1      <= 1'b0;
	end
	
	// Assign wires or registers (need to check) to outputs.
	assign wr_reg_strb 					= wr_reg_strb_reg;
	assign wr_reg_index					= wr_reg_index_reg;
	assign wr_reg_output					= wr_reg_output_reg; 
	assign rd_reg_index					= rd_reg_index_reg;
	assign reg_attr						= reg_attr_reg;
	assign issue_sd_cmd_strb			= issue_sd_cmd_strb_reg;
	assign issue_abort_cmd				= issue_abort_cmd_reg;
	assign wr_descr_table_strb		   = wr_descr_table_strb_reg;
	// To save information to System Memory RAM.
	assign wr_ram_addr					= wr_ram_addr_reg;
	assign wr_ram_data					= wr_ram_data_reg;
	assign wr_ram_enb						= wr_ram_enb_reg;          
	assign dat_tf_adma_proc				= dat_tf_adma_proc_reg;
	
	// Decide which rd_reg_index to use internal to this module.
	//always@(posedge clk)
//	begin
//		if (reset)
//			rd_reg_index_int	<= 12'h000;     
//		else 
//			rd_reg_index_int	<= rd_reg_index_reg;
//	end
	
	// Set up delays.
	always@(posedge clk)
	begin
		if (reset) begin
			data_in_strb_z1	         <= 1'b0;          // for saving the descr table
			data_in_strb_z2	         <= 1'b0;          // for saving the data
         normal_int_stat_bit_1_z1   <= 1'b0;
		end
		else begin
			data_in_strb_z1            <= data_in_strb;  // for creating a descr table	
			data_in_strb_z2	         <= data_in_strb_z1;
         normal_int_stat_bit_1_z1   <= normal_int_stat_bit_1;
		end
	end                                                                         	

	//-------------------------------------------------------------------------
	// We need a x clocks counter.  It takes 1 clock to get a reading for the
	// memory map from the host controller.  However, we'll use x clocks
	// to give it some room.  We also use this counter if we have two writes
	// in the row.  This also gives it some room.
	//-------------------------------------------------------------------------
	defparam readClksCntr_u1.dw 	= 3;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam readClksCntr_u1.max	= 3'h3;	
	//-------------------------------------------------------------------------
	CounterSeq readClksCntr_u1(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_input_strb || wr_reg_strb_reg),   	 	
		.cntr(), 
		.strb(read_clks_tout) 
	);	  

	//-------------------------------------------------------------------------
	// If we waited for 1 second and a command hasn't been responded yet,
	// get out of the state machine.
	//-------------------------------------------------------------------------
	defparam readToClksCntr.dw 	= 28;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam readToClksCntr.max	= 28'h2FAF080;	
	//-------------------------------------------------------------------------
	CounterSeq readToClksCntr(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_input_strb),   	 	
		.cntr(), 
		.strb(rd_to_strb) 
	);		  

	// Update cmd_complete, becareful, other registers are written to 
	// rd_reg_input.  From normal_int_stat.
	always@(posedge clk)
	begin
		if (reset) 
			cmd_complete	<= 1'b0; 
		else
			cmd_complete	<= rd_reg_input[0];
	end									  

	// After sending cmd24, we need to see if the card is ready
	// to accept data.  This is from the Card Status field.
	always@(posedge clk)
	begin
		if (reset) 
			rdy_for_dat	<= 1'b0; 		    
		else
			rdy_for_dat	<= rd_reg_input[8];
	end									  

	// If command 24 is ready for data, we can start the adma state machine.
	// This will start to send out data to the sd card.
//	always@(posedge clk)
//	begin
//		if (reset) 
//			strt_adma_strb	<= 1'b0; 		
//		else if (read_clks_tout && (state == ste_get_resp_wt))
//			strt_adma_strb	<= rd_reg_input[8];
//		else										 						  
//			strt_adma_strb	<= 1'b0;
//	end
	
	// Update transfer_complete, becareful, other registers are written to 
	// rd_reg_input.  From normal_int_stat (030h).
	always@(posedge clk)
	begin
		if (reset) 
			normal_int_stat_bit_1	<= 1'b0;
		else if (rd_reg_input[1] && (state == ste_wait_for_tf_compl_int_wt))
			normal_int_stat_bit_1	<= 1'b1;
		else
			normal_int_stat_bit_1	<= 1'b0;
	end     
	
	// Update transfer_complete when normal_int_stat_bit_1 has a rising edge. 
	always@(posedge clk)
	begin
		if (reset) 
			tf_complete	<= 1'b0;
		else if (~normal_int_stat_bit_1_z1 && normal_int_stat_bit_1)
			tf_complete	<= 1'b1;
		else
			tf_complete	<= 1'b0;
	end     
	
	// Select single block or multiple blocks write base on tf_mode.
	always@(tf_mode[5])
	begin
		case (tf_mode[5])
			// Single block transfer.							
			1'b0	   :	command <= {{2{1'b0}},6'h18,{2{1'b0}},1'b1,1'b0,1'b0,1'b0,1'b1,1'b0};
			// Multi blocks transfer.							
			1'b1	   :	command <= {{2{1'b0}},6'h19,{2{1'b0}},1'b1,1'b0,1'b0,1'b0,1'b1,1'b0};
			default 	: 	command <= {16{1'b0}};
		endcase
	end                            
	
	////////////////////////////////////////////////////////////////////////////
	// This state machine in conjuction with adma2.v will send the data to the sd card.
	////////////////////////////////////////////////////////////////////////////
   parameter ste_start  					         = 26'b00_0000_0000_0000_0000_0000_0001;					
   parameter ste_create_descr_table					= 26'b00_0000_0000_0000_0000_0000_0010;			
   parameter ste_set_adma_sys_addr_reg	  			= 26'b00_0000_0000_0000_0000_0000_0100;			
   parameter ste_set_adma_sys_addr_reg_wt  		= 26'b00_0000_0000_0000_0000_0000_1000;			   
   parameter ste_set_block_size_reg  				= 26'b00_0000_0000_0000_0000_0001_0000;			
   parameter ste_set_blk_count_reg  				= 26'b00_0000_0000_0000_0000_0010_0000;			
   parameter ste_set_blk_count_reg_wt  			= 26'b00_0000_0000_0000_0000_0100_0000;			
   parameter ste_set_argument_1_reg  				= 26'b00_0000_0000_0000_0000_1000_0000;			
   parameter ste_set_argument_1_reg_wt 			= 26'b00_0000_0000_0000_0001_0000_0000;			
   parameter ste_set_tf_mode_reg  					= 26'b00_0000_0000_0000_0010_0000_0000;			
   parameter ste_set_tf_mode_reg_wt					= 26'b00_0000_0000_0000_0100_0000_0000;			
   parameter ste_set_cmd_reg  						= 26'b00_0000_0000_0000_1000_0000_0000;			
   parameter ste_set_cmd_reg_wt 						= 26'b00_0000_0000_0001_0000_0000_0000;			
   parameter ste_wait_for_cmd_cmplt_int 			= 26'b00_0000_0000_0010_0000_0000_0000;			
   parameter ste_wait_for_cmd_cmplt_int_wt		= 26'b00_0000_0000_0100_0000_0000_0000;			
   parameter ste_clr_cmd_compl						= 26'b00_0000_0000_1000_0000_0000_0000;			
   parameter ste_clr_cmd_compl_wt					= 26'b00_0000_0001_0000_0000_0000_0000;			
   parameter ste_get_resp 								= 26'b00_0000_0010_0000_0000_0000_0000;			
   parameter ste_get_resp_wt							= 26'b00_0000_0100_0000_0000_0000_0000;			
   parameter ste_strt_fifo 							= 26'b00_0000_1000_0000_0000_0000_0000;		   
   parameter ste_strt_fifo_wt							= 26'b00_0001_0000_0000_0000_0000_0000;			
   parameter ste_wait_for_tf_compl_int 			= 26'b00_0010_0000_0000_0000_0000_0000;			
   parameter ste_wait_for_tf_compl_int_wt			= 26'b00_0100_0000_0000_0000_0000_0000;			
   parameter ste_clear_tf_compl_int 				= 26'b00_1000_0000_0000_0000_0000_0000;			
   parameter ste_clear_tf_compl_int_wt 			= 26'b01_0000_0000_0000_0000_0000_0000;			
   parameter ste_end 									= 26'b10_0000_0000_0000_0000_0000_0000;			

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="ste_start" *) 
	reg [25:0] state = ste_start;

   always@(posedge clk)
      if (reset) begin
         state 								<= ste_start;                 //                
         //<outputs> <= <initial_values>;
			issue_sd_cmd_strb_reg			<= 1'b0;
			issue_abort_cmd_reg				<= 1'b0;
			rd_input_strb						<= 1'b0;
			rd_reg_index_reg 					<= 12'h000;
			wr_reg_strb_reg					<= 1'b0;
			wr_reg_index_reg					<= 12'h000;
			wr_reg_output_reg					<= {32{1'b0}};
			reg_attr_reg						<= 3'h0; // type of bit write     
         wr_descr_table_strb_reg       <= 1'b0;
         strt_fifo_strb				      <= 1'b0;
         strt_adma_strb	               <= 1'b0;
			dat_tf_adma_proc_reg				<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
            ste_start : begin                                        // 24'b0000_0000_0000_0000_0000_0001;
               if (start_data_tf_strb)
                  state 					<= ste_create_descr_table;		
               else if (!start_data_tf_strb)
                  state 					<= ste_start;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0; // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;      
					dat_tf_adma_proc_reg		<= 1'b0;
            end
            ste_create_descr_table : begin								   // 24'b0000_0000_0000_0000_0000_0010
               state 						<= ste_set_adma_sys_addr_reg;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0; // type of bit write 
               // start to write the descriptor tables in bram
               // this will take 47 clocks.
               wr_descr_table_strb_reg <= 1'b1;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;      
					dat_tf_adma_proc_reg		<= 1'b1;				
            end
            ste_set_adma_sys_addr_reg : begin								// 24'b0000_0000_0000_0000_0000_0100
					// Always starts at register 1.
					state 						<= ste_set_adma_sys_addr_reg_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b1;                      // Start strobe.
					wr_reg_index_reg			<= 12'h058;
					// Location of first decriptor line, 00000000 00000001h.
					wr_reg_output_reg			<= 32'h00000001; 
					reg_attr_reg				<= 3'h0; // type of bit write
               strt_fifo_strb			   <= 1'b0;     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_set_adma_sys_addr_reg_wt : begin							// 24'b0000_0000_0000_0000_0000_1000		 				  
               if (read_clks_tout)
                  state 					<= ste_set_block_size_reg;
               else if (!read_clks_tout)
                  state 					<= ste_set_adma_sys_addr_reg_wt;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;                      // End strobe.
					wr_reg_index_reg			<= 12'h058;
					// Location of first decriptor line, 00000000 00000001h.
					wr_reg_output_reg			<= 32'h00000001; 
					reg_attr_reg				<= 3'h0; // type of bit write           
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_set_block_size_reg : begin									// 24'b0000_0000_0000_0000_0001_0000	 
					// Only used for SDMA, therefore, we will not update
					// this register.	 ADMA uses default 512 bytes block size.
					state 						<= ste_set_blk_count_reg;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h004;
					wr_reg_output_reg			<= {{20{1'b0}}, tf_blk_size};
					reg_attr_reg				<= 3'h0; // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_set_blk_count_reg : begin									   // 24'b0000_0000_0000_0000_0010_0000
					state 						<= ste_set_blk_count_reg_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b1;
					wr_reg_index_reg			<= 12'h006;
					wr_reg_output_reg			<= {{16{1'b0}}, blk_count};
					reg_attr_reg				<= 3'h0; // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end											
            ste_set_blk_count_reg_wt : begin								   // 24'b0000_0000_0000_0000_0100_0000						 				  
               if (read_clks_tout)
                  state 					<= ste_set_argument_1_reg;
               else if (!read_clks_tout)
                  state 					<= ste_set_blk_count_reg_wt;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h006;
					wr_reg_output_reg			<= {{16{1'b0}}, blk_count};
					reg_attr_reg				<= 3'h0; // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_set_argument_1_reg : begin  								   // 24'b0000_0000_0000_0000_1000_0000
					state 						<= ste_set_argument_1_reg_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b1;
					wr_reg_index_reg 			<= 12'h008;
					wr_reg_output_reg			<= argument;	// Data Address
					reg_attr_reg				<= 3'h0; 		// type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;
					dat_tf_adma_proc_reg		<= 1'b1;	
            end										  
            ste_set_argument_1_reg_wt : begin							   // 24'b0000_0000_0000_0001_0000_0000						  								 				  
               if (read_clks_tout)
                  state 					<= ste_set_tf_mode_reg;
               else if (!read_clks_tout)
                  state 					<= ste_set_argument_1_reg_wt;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg 			<= 12'h008;
					wr_reg_output_reg			<= argument;
					reg_attr_reg				<= 3'h0; // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0; 
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_set_tf_mode_reg : begin									   // 24'b0000_0000_0000_0010_0000_0000
					state 						<= ste_set_tf_mode_reg_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b1;
					wr_reg_index_reg 			<= 12'h00C;
					wr_reg_output_reg			<= {{16{1'b0}}, tf_mode};
					reg_attr_reg				<= 3'h0; // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0; 
					dat_tf_adma_proc_reg		<= 1'b1;	
            end										
            ste_set_tf_mode_reg_wt : begin								   // 24'b0000_0000_0000_0100_0000_0000					  				  				  								 				  
               if (read_clks_tout)
                  state 					<= ste_set_cmd_reg;
               else if (!read_clks_tout)
                  state 					<= ste_set_tf_mode_reg_wt;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg 			<= 12'h00C;
					wr_reg_output_reg			<= {{16{1'b0}}, tf_mode};
					reg_attr_reg				<= 3'h0;                      // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	                     
            end                                                      
            ste_set_cmd_reg : begin											   // 24'b0000_0000_0000_1000_0000_0000
					state 						<= ste_set_cmd_reg_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b1;
					// need to check if it is free before
					// writing to this register.
					// When we write this register to the sd_host_controller,
					// it will start to send out the command using
					// sdc_snd_dat_1_bit.  When the response comes back from this module,
					// it will be written to the response register.  Based on the
					// response register we will look at the R1 packet to see if
					// the SD card is ready to accept data or return data.  
					// Bit 8 of the card_compl_packet will tell us this.
					// If it is ready to accept data, we will start the ADMA2 state
					// machine.  This will start to send the data to the SD card.
					wr_reg_index_reg 			<= 12'h00E;
					wr_reg_output_reg			<= {{16{1'b0}}, command};
					reg_attr_reg				<= 3'h0;                   // type of bit write      
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end								
            ste_set_cmd_reg_wt : begin										// 26'b00_0000_0000_0001_0000_0000_0000																		 			  				  				  								 				  
               if (read_clks_tout)
                  state 					<= ste_wait_for_cmd_cmplt_int;
               else if (!read_clks_tout)
                  state 					<= ste_set_cmd_reg_wt;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000; 
					wr_reg_strb_reg			<= 1'b0;										 
					wr_reg_index_reg 			<= 12'h00E;
					wr_reg_output_reg			<= {{16{1'b0}}, command};
					reg_attr_reg				<= 3'h0;                   // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                       
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_wait_for_cmd_cmplt_int : begin 							// 26'b00_0000_0000_0010_0000_0000_0000
               state 						<= ste_wait_for_cmd_cmplt_int_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b1;                   // Start of strobe.
					rd_reg_index_reg 			<= 12'h030;                // normal_int_stat
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                   // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                       
					dat_tf_adma_proc_reg		<= 1'b1;	
            end						
            ste_wait_for_cmd_cmplt_int_wt : begin						// 26'b00_0000_0000_0100_0000_0000_0000
               if (cmd_complete)
                  state 					<= ste_clr_cmd_compl;		  
					// If time is up and we don't get a command complete
					// interrupt, get out of the state machine.	 
					// We will timeout after 1 second.
               else if (rd_to_strb && !cmd_complete)
                  state 					<= ste_end;	  
					// else wait here
               else
                  state 					<= ste_wait_for_cmd_cmplt_int_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;                   // End of strobe.
					rd_reg_index_reg 			<= 12'h030;                // normal_int_stat
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                   // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                       
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_clr_cmd_compl : begin 										// 26'b00_0000_0000_1000_0000_0000_0000
					state 						<= ste_clr_cmd_compl_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;                   
					wr_reg_strb_reg			<= 1'b1;
					wr_reg_index_reg 			<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg			<= {{16{1'b0}},{15{1'b0}},1'b1};
					reg_attr_reg				<= 3'h3; // RW1C                   
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end										
            ste_clr_cmd_compl_wt : begin									// 26'b00_0000_0001_0000_0000_0000_0000;		
               if (read_clks_tout)
                  state 					<= ste_get_resp;
               else if (!read_clks_tout)
                  state 					<= ste_clr_cmd_compl_wt;
               else
                  state 					<= ste_start;	 
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;                   
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg 			<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg			<= {{16{1'b0}},{15{1'b0}},1'b1};
					reg_attr_reg				<= 3'h3; // RW1C                   
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	 
				end
            ste_get_resp : begin											// 26'b00_0000_0010_0000_0000_0000_0000
					state 						<= ste_get_resp_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b1;
					// May need to write code to get some information
					// out of the response register.
					// We will read the R1 response coming back to see
					// if the sd card is ready to be written or read.
					// This is bit 8 of the card _compl_ packet (READY_FOR_DATA).
					// This is from the Card Status field of the response.
					// We can activate the ADMA state machine if the card is
					// ready to accept data.
					rd_reg_index_reg 			<= 12'h010; // Response register
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;    // type of bit write      
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end														 
            ste_get_resp_wt : begin										// 26'b00_0000_0100_0000_0000_0000_0000		
					// If the card is ready for data, start to fill up the
               // fifo.
               if (read_clks_tout && rdy_for_dat)
                  state 					<= ste_strt_fifo;
               else if (!read_clks_tout)
                  state 					<= ste_get_resp_wt;		 
					// If card is not ready for data, quit this process.
               else
                  state 					<= ste_start;										
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h010;             // Response register 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end			 
            ste_strt_fifo : begin										// 26'b00_0000_1000_0000_0000_0000_0000
               // This is where we start to do the transfer.
               // First we fill up the fifo then we start the transfer.
               state 					   <= ste_strt_fifo_wt;										
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h010;             // Response register 
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write      
               wr_descr_table_strb_reg <= 1'b0;                
               strt_fifo_strb				<= 1'b1;                // start to fill the puc fifo
               strt_adma_strb	         <= 1'b0;                       
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_strt_fifo_wt : begin				 		         // 26'b00_0001_0000_0000_0000_0000_0000
               if(fifo_rdy_strb)
                  state 				   <= ste_wait_for_tf_compl_int;	
               else                    
                  state 					<= ste_strt_fifo_wt;	
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0; 
					rd_reg_index_reg 			<= 12'h030;   
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;   
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                                        
					dat_tf_adma_proc_reg		<= 1'b1;	
            end	
            ste_wait_for_tf_compl_int : begin				 		// 26'b00_0010_0000_0000_0000_0000_0000
               // When the fifo is ready, we start the adma2
               // state machine to send out the data.
               // Also, here we wait for the transfer to complete.
               // All 16 blocks of data.  We poll register h030
               // to see if the transfer is completed.
               state 						<= ste_wait_for_tf_compl_int_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b1; 
					rd_reg_index_reg 			<= 12'h030;   
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write    
               wr_descr_table_strb_reg <= 1'b0;                  
               strt_fifo_strb				<= 1'b0;                
               strt_adma_strb	         <= 1'b1;                // starts the adma2 state machine
					dat_tf_adma_proc_reg		<= 1'b1;	
            end				
            ste_wait_for_tf_compl_int_wt : begin  					// 26'b00_0100_0000_0000_0000_0000_0000
					// We stay here until the ADMA2 is completed with all
					// the block transfers.
               if (tf_complete)
                  state 					<= ste_clear_tf_compl_int;
					// Need to figure out when the transfer is not complete
					// and if we are stuck.
               else if (rd_to_strb && !tf_complete)
                  state 					<= ste_end;						 
               else
                  state 					<= ste_wait_for_tf_compl_int_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;                
					rd_reg_index_reg 			<= 12'h030;    
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;   
               strt_fifo_strb				<= 1'b0;                                       
               strt_adma_strb	         <= 1'b0;  
					dat_tf_adma_proc_reg		<= 1'b1;	
            end
            ste_clear_tf_compl_int : begin 							// 26'b00_1000_0000_0000_0000_0000_0000
					state 						<= ste_clear_tf_compl_int_wt;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;                // 
					issue_abort_cmd_reg		<= 1'b0;                // 
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;    
					wr_reg_strb_reg			<= 1'b1;
					// need to read reg h030 before we write to it
					wr_reg_index_reg 			<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg			<= {{16{1'b0}},{14{1'b0}},1'b1,1'b0};
					reg_attr_reg				<= 3'h3;                // RW1C                  
               wr_descr_table_strb_reg <= 1'b0;   
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b1;	
            end				
            ste_clear_tf_compl_int_wt : begin						// 26'b01_0000_0000_0000_0000_0000_0000	 													 			  				  				  								 				  
               if (read_clks_tout)
                  state 					<= ste_end;
               else if (!read_clks_tout)
                  state 					<= ste_clear_tf_compl_int_wt;
               else
                  state 					<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;    
					wr_reg_strb_reg			<= 1'b0;
					// need to read reg h030 before we write to it
					wr_reg_index_reg 			<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg			<= {{16{1'b0}},{14{1'b0}},1'b1,1'b0};
					reg_attr_reg				<= 3'h3;                // RW1C             
               wr_descr_table_strb_reg <= 1'b0;   
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                           
					dat_tf_adma_proc_reg		<= 1'b1;	
            end											 
            ste_end : begin  											   // 26'b10_0000_0000_0000_0000_0000_0000
					state 						<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;    
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;   
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b0;	
            end
            default: begin  // Fault Recovery
               state 						<= ste_start;
               //<outputs> <= <values>;
					issue_sd_cmd_strb_reg	<= 1'b0;
					issue_abort_cmd_reg		<= 1'b0;
					rd_input_strb				<= 1'b0;
					rd_reg_index_reg 			<= 12'h000;    
					wr_reg_strb_reg			<= 1'b0;
					wr_reg_index_reg			<= 12'h000;
					wr_reg_output_reg			<= {32{1'b0}};
					reg_attr_reg				<= 3'h0;                // type of bit write     
               wr_descr_table_strb_reg <= 1'b0;   
               strt_fifo_strb				<= 1'b0;
               strt_adma_strb	         <= 1'b0;                      
					dat_tf_adma_proc_reg		<= 1'b0;	
	    		end
         endcase							
	////////////////////////////////////////////////////////////////////////////
	// End of state machine.
	////////////////////////////////////////////////////////////////////////////
	             
	
endmodule
