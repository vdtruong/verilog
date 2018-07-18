`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// company: 
// Engineer: 
// 
// Create Date:    20:06:24 10/05/2012 
// Update Date:             01/13/2013
// Design Name: 
// Module Name:    issue_sd_cmd 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 	This module implements 3.7.1.1 The Sequence to
//						Issue a SD Command.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module issue_sd_cmd(
	 input            clk,
	 input				reset,
	 input				issue_sd_cmd_strb,// strobe to get out of start state
    //input 				cmd_with_tf_compl_int,
    // The following gets information from puc command 0x0011.
	 input	[5:0]		cmd_index,
	 input	[31:0] 	argument,
	 input	[1:0]		command_type,     // may want to check for cmd12
	 input				data_pres_select, // may want to check for cmd12
	 input				cmd_indx_chk_enb, // may want to check for cmd12
	 input				cmd_crc_chk_enb,  // may want to check for cmd12
	 input	[1:0]		resp_type_select, // may want to check for cmd12
    // End for command 0x0011.
	 input				issue_cmd_with_busy,
	 input				issue_abort_cmd_flag,
	 // For use with sd_host_controller.
	 output	[11:0]	rd_reg_index,
	 input 	[127:0]	rd_reg_input,
	 output				wr_reg_strb,
	 output	[11:0]	wr_reg_index,
	 output 	[31:0]	wr_reg_output,
	 output 	[2:0]		reg_attr,
	 output				fin_a_cmd_strb,   // start the finalize a command seq.
	 output				iss_sd_cmd_proc   // indicates that we are in this module still
    );
	
	// Registers
	reg 			cmd_line_free;
	reg 			dat_line_free;
	//reg 			cmd_compl;
	//reg 			tf_compl;
	reg 			wr_reg_strb_reg;
	//reg 			//new_cmd_set_strb_reg;
	reg [11:0] 	rd_reg_index_reg;
	reg [11:0] 	wr_reg_index_reg;
	reg [31:0]	wr_reg_output_reg;
	reg [2:0]	reg_attr_reg;
	reg			fin_a_cmd_strb_reg;
	reg 			iss_sd_cmd_proc_reg; 
	// need 3 clocks to get back reading from host controller
	reg			rd_reg_strb; 
   //reg         issue_abort_cmd_flag;
	
	// Wire
	wire			read_clks_tout;
   wire [5:0]  cmd_indx;      // command index to send to sdc
   wire [31:0] arg;           // argument for cmd8
	
	// Initialize sequential logic
	initial			
	begin
		cmd_line_free 				<= 1'b0;
		dat_line_free				<= 1'b0;
//		cmd_compl					<= 1'b0;
//		tf_compl						<= 1'b0;
		wr_reg_strb_reg			<= 1'b0;
		//new_cmd_set_strb_reg	<= 1'b0;
		rd_reg_index_reg			<= 12'h000;
		wr_reg_index_reg			<= 12'h000;
		wr_reg_output_reg			<= 32'h00000000;
		reg_attr_reg				<= 3'h0;
		fin_a_cmd_strb_reg		<= 1'b0;
		iss_sd_cmd_proc_reg		<= 1'b0;
		rd_reg_strb					<= 1'b0;
		//issue_abort_cmd_flag		<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign wr_reg_strb 			= wr_reg_strb_reg;
	//assign new_cmd_set_strb = //new_cmd_set_strb_reg;
	assign rd_reg_index			= rd_reg_index_reg;
	assign wr_reg_index			= wr_reg_index_reg;
	assign wr_reg_output			= wr_reg_output_reg;
	assign reg_attr				= reg_attr_reg;
	assign fin_a_cmd_strb		= fin_a_cmd_strb_reg;
	assign iss_sd_cmd_proc		= iss_sd_cmd_proc_reg;
   assign cmd_indx            = (issue_abort_cmd_flag == 1'b1) ? 6'h0C : cmd_index;                     // send cmd 12 if true
   assign arg                 = (issue_abort_cmd_flag == 1'b1) ? {{20{1'b0}},4'h1,8'hAA} : argument;    // if for cmd 12 is true 
	
	// Update cmd_line_free.  Present State Register (Offset 024h).
	always@(posedge clk)
	begin
		if (reset) 
			cmd_line_free 	<= 1'b0; 	
		else if (rd_reg_input[0] == 0) 
			cmd_line_free 	<= 1'b1;
		else 
			cmd_line_free	<= 1'b0;
	end
	
//   always @(rd_reg_input)
//	begin
//      if (rd_reg_input[0] == 0)  
//			cmd_line_free 	<= 1'b1;
//		else
//			cmd_line_free	<= 1'b0;
//   end
	
	// Update dat_line_free, becareful, other registers are written to 
	// rd_reg_input.  Present State Register (Offset 024h).
	// Use sequential for polling.
	// Combinational may not react unless
	// we have a change in rd_reg_input.
	always@(posedge clk)
	begin
		if (reset)
			dat_line_free	<= 1'b0;
		else if (rd_reg_input[1] == 0) 
			dat_line_free 	<= 1'b1;
		else 
			dat_line_free	<= 1'b0;
	end
	
//   always @(rd_reg_input)
//	begin
//      if (rd_reg_input[1] == 0)  
//			dat_line_free 	<= 1'b1;
//		else
//			dat_line_free	<= 1'b0;
//   end
	
	// Update cmd_compl, becareful, other registers are written to 
	// rd_reg_input.  From normal int status register.
//	always@(posedge clk)
//	begin
//		if (reset) begin
//			cmd_compl 	<= 1'b0; 		
//		end
//		else begin
//			cmd_compl	<= rd_reg_input[0];
//		end
//	end
	
	// Update trasfer_compl, becareful, other registers are written to 
	// rd_reg_input.  From normal int status register (030h).
//	always@(posedge clk)
//	begin
//		if (reset) begin
//			tf_compl	<= 1'b0; 		
//		end
//		else begin
//			tf_compl	<= rd_reg_input[1];
//		end
//	end 

	//-------------------------------------------------------------------------
	// We need a x clocks counter.  It takes 1 clock to get a reading for the
	// memory map from the host controller.  However, we'll use x clocks
	// to give it some room.  We also use this counter if we have two writes
	// in the row.  This also gives it some room.
	//-------------------------------------------------------------------------
	defparam readClksCntr_u1.dw 	= 3;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam readClksCntr_u1.max	= 3'h5;	
	//-------------------------------------------------------------------------
	CounterSeq readClksCntr_u1(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_reg_strb || wr_reg_strb_reg),   	 	
		.cntr(), 
		.strb(read_clks_tout) 
	);
	
	// State machine to issue a sd command without data.
   parameter state_start  						= 12'b0000_0000_0001;
	parameter state_chk_inhb_cmd  			= 12'b0000_0000_0010;	  
	parameter state_rd_wait  					= 12'b0000_0000_0100;
   parameter state_issue_cmd_with_busy  	= 12'b0000_0000_1000;
   parameter state_issue_abort_cmd_query	= 12'b0000_0001_0000;
   parameter state_chk_inhb_dat				= 12'b0000_0010_0000;
   parameter state_rd_wait2					= 12'b0000_0100_0000;
   parameter state_set_arg1				  	= 12'b0000_1000_0000; 
   parameter state_wr_strb_wait				= 12'b0001_0000_0000;
   parameter state_send_cmd  					= 12'b0010_0000_0000;
   parameter state_wt_send  					= 12'b0100_0000_0000;
   parameter state_end 							= 12'b1000_0000_0000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [11:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         // Outputs
			rd_reg_index_reg 				<= 12'h000;
			wr_reg_strb_reg				<= 1'b0;
			wr_reg_index_reg 				<= 12'h000;
			wr_reg_output_reg				<= {32{1'b0}};
			reg_attr_reg					<= 3'h0;
			fin_a_cmd_strb_reg			<= 1'b0;
			iss_sd_cmd_proc_reg			<= 1'b0;
			rd_reg_strb						<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
				state_start : begin	 					// 12'b0000_0000_0001
               if (issue_sd_cmd_strb)
                  state 				<= state_chk_inhb_cmd;
               else if (!issue_sd_cmd_strb)
                  state 				<= state_start;
               else
                  state 				<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b0;
					rd_reg_strb				<= 1'b0;
				end
            state_chk_inhb_cmd : begin				// 12'b0000_0000_0010	 
               state 					<= state_rd_wait;
               // Outputs
					rd_reg_index_reg 		<= 12'h024;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b1;				
            end 
            state_rd_wait : begin					// 12'b0000_0000_0100
               if (read_clks_tout && cmd_line_free)
                  state 				<= state_issue_cmd_with_busy;
               else if (!read_clks_tout)
                  state 				<= state_rd_wait;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h024;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;				
            end
            state_issue_cmd_with_busy : begin	// 12'b0000_0000_1000
               if (issue_cmd_with_busy)
                  state		 			<= state_issue_abort_cmd_query;
               else if (!issue_cmd_with_busy)
                  //state <= state_wait_for_clear;
						state 				<= state_set_arg1;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;    // type of bit write
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end
            state_issue_abort_cmd_query : begin	// 12'b0000_0001_0000
               if (issue_abort_cmd_flag)
                  //state <= state_issue_abort_cmd_send;
						state 				<= state_set_arg1;
               else if (!issue_abort_cmd_flag)
                  state 				<= state_chk_inhb_dat;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end
            state_chk_inhb_dat : begin	// 12'b0000_0010_0000					
               state 					<= state_rd_wait2;
               // Outputs
					rd_reg_index_reg 		<= 12'h024;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b1;
            end	 
            state_rd_wait2 : begin	// 12'b0000_0100_0000
               if (read_clks_tout && dat_line_free)
                  state 				<= state_set_arg1;
               else if (!read_clks_tout)
                  state 				<= state_rd_wait2;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end
            state_set_arg1 : begin	// 12'b0000_1000_0000 
               state 					<= state_wr_strb_wait;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					// Update the argument field of the send command.
					wr_reg_index_reg 		<= 12'h008;
					wr_reg_output_reg		<= arg;
					reg_attr_reg			<= 3'h0; // type of bit write
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end 																		  
				// Create a strobe and
				// gives the host controller time to write to the register.	
				// This may be necessary since we are writting two registers
				// next to one another.
            state_wr_strb_wait : begin	// 12'b0001 0000 0000 				  		  
               if (read_clks_tout)
               	state 				<= state_send_cmd;	
               else if (!read_clks_tout)
                  state 				<= state_wr_strb_wait;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;							 
					wr_reg_index_reg 		<= 12'h008;
					wr_reg_output_reg		<= arg;
					reg_attr_reg			<= 3'h0; 
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end
            state_send_cmd : begin	// 12'b0010 0000 0000 
               state 					<= state_wt_send;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					// Fill up the Command Register (Offset 00Eh) in the 
					// SD host controller.  This command will set
					// off the new_cmd_set_strb in the host controller
					// and starts a send command.
					// Becareful, sdc_clk is slower than system clock.
					// If you are waiting for a response from the sd card,
					// make sure you have a mechanism for waiting or 
					// enough clocks to get the response back.
					wr_reg_index_reg 		<= 12'h00E;
					wr_reg_output_reg		<= {{16{1'b0}},{2{1'b0}},cmd_indx,	
													command_type,data_pres_select,
													cmd_indx_chk_enb,cmd_crc_chk_enb,{1'b0},
													resp_type_select};
					reg_attr_reg			<= 3'h0; // type of bit write
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end										
            state_wt_send : begin	// 12'b0100 0000 0000 	  				  		  
               if (read_clks_tout)
               	state 				<= state_end;	
               else if (!read_clks_tout)
                  state 				<= state_wt_send;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					// Keep the index and data available a bit longer.
					wr_reg_index_reg 		<= 12'h00E;
					wr_reg_output_reg		<= {{16{1'b0}},{2{1'b0}},cmd_indx,	
													command_type,data_pres_select,
													cmd_indx_chk_enb,cmd_crc_chk_enb,{1'b0},
													resp_type_select};
					reg_attr_reg			<= 3'h0; // type of bit write
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end
            state_end : begin			// 12'b1000 0000 0000
               state 					<= state_start;
					// Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; // type of bit write
					// triggers the finish a command module
					fin_a_cmd_strb_reg	<= 1'b1;
					iss_sd_cmd_proc_reg	<= 1'b1;
					rd_reg_strb				<= 1'b0;
            end            
            default: begin  // Fault Recovery
               state 					<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; // type of bit write
					fin_a_cmd_strb_reg	<= 1'b0;
					iss_sd_cmd_proc_reg	<= 1'b0;
					rd_reg_strb				<= 1'b0;
				end
			endcase

endmodule
