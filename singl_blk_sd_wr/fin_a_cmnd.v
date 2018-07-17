`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    10:09:49 12/04/2012 
// Design Name: 
// Module Name:    fin_a_cmnd 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description:  	3.7.1.2 The Sequence to Finalize a Command
//						Figure 3-12 shows the sequence to finalize a SD Command. 
//						There is a possibility that some errors
//						(Command Index/End bit/CRC/Timeout Error) occur during 
//						this sequence.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module fin_a_cmnd(
	input            	clk,
	input					reset,
	input					fin_a_cmd_strb, 	// start the finalize a command seq.
   input		[5:0]		cmd_index,
	input 				cmd_with_tf_compl_int, 
	input					end_bit_det_strb,	// finished sending out command
	// For use with sd_host_controller.
	output	[11:0]	rd_reg_index,
	input 	[127:0]	rd_reg_input,
	output				wr_reg_strb,
	output	[11:0]	wr_reg_index,
	output 	[31:0]	wr_reg_output,
	output 	[2:0]		reg_attr, 
	 
	output	[15:0]	err_int_stat,		// any error from response
	output				fin_a_cmd_proc,	// indicates we're in this module
	output				fin_cmnd_strb 		// finished with command
   );
	 
	// Set the echo-back pattern.
	parameter echo_bk_patt 	= 8'hAA;
	
	// Registers
	reg 				cmd_compl;
	reg 				tf_compl;
	reg 				wr_reg_strb_reg;
	reg 	[11:0] 	rd_reg_index_reg;
	reg 	[11:0]	wr_reg_index_reg;
	reg 	[31:0]	wr_reg_output_reg;
	reg 	[2:0]		reg_attr_reg;
	reg	[15:0]	err_int_stat_reg;
	reg				fin_a_cmd_proc_reg;
	// set this to one when we reach the end state.
	reg				fin_cmnd_strb_reg;  
	// need 3 clocks to get back reading from host controller
	reg				rd_reg_strb;
	reg				err; // any error sets on the err int stat reg.
	reg				end_bit_det_strb_z1; // delay
	
	// Wire								
	// time needed to get data from the host controller
	wire				read_clks_tout;
	// Get out of waiting if has not received a response from a cmnd.
	wire				rd_to_strb;	
	
	// Initialize sequential logic
	initial			
	begin
		cmd_compl				<= 1'b0;
		tf_compl					<= 1'b0;
		wr_reg_strb_reg		<= 1'b0;
		rd_reg_index_reg		<= 12'h000;
		wr_reg_index_reg		<= 12'h000;
		wr_reg_output_reg		<= 32'h00000000;
		reg_attr_reg			<= 3'h0;
		err_int_stat_reg		<= 16'h0000;
		fin_a_cmd_proc_reg	<= 1'b0;
		fin_cmnd_strb_reg		<= 1'b0;
		rd_reg_strb				<= 1'b0;
		err						<= 1'b0;	
		end_bit_det_strb_z1	<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign rd_reg_index		= rd_reg_index_reg;
	assign wr_reg_strb 		= wr_reg_strb_reg;
	assign wr_reg_index		= wr_reg_index_reg;
	assign wr_reg_output		= wr_reg_output_reg;
	assign reg_attr			= reg_attr_reg;
	assign err_int_stat		= err_int_stat_reg;
	assign fin_a_cmd_proc   = fin_a_cmd_proc_reg;
	assign fin_cmnd_strb		= fin_cmnd_strb_reg;
	
	// Create delay.
	always@(posedge clk)
	begin
		if (reset) 						  					
			end_bit_det_strb_z1	<= 1'b0;
		else 										 						 			
			end_bit_det_strb_z1	<= end_bit_det_strb;
	end
	
	// Update cmd_compl, becareful, other registers are written to 
	// rd_reg_input.  From normal int status register.
	always@(posedge clk)
	begin
		if (reset) 
			cmd_compl 	<= 1'b0;
		else 
			cmd_compl	<= rd_reg_input[0];
	end
	
	// Update trasfer_compl, becareful, other registers are written to 
	// rd_reg_input.  From normal int status register (030h).
	always@(posedge clk)
	begin
		if (reset) begin
			tf_compl	<= 1'b0; 		
		end
		else begin
			tf_compl	<= rd_reg_input[1];
		end
	end
	
	// We need to find out if we have any error at all.
	always@(posedge clk)
	begin
		if (reset) 
			err	<= 1'b0;	  
		else if (rd_reg_input != 0)
			// If err int stat register is not 0
			// we have some error(s).
			err 	<= 1'b1;
		else 
			err	<= 1'b0;		
	end
	
	// Update the error status, becareful, other registers are written to 
	// rd_reg_input.  From Response register (010h).
	// We'll update this code as we go on.  This is for the check
	// response data state.  May need to write code to return the
	// content of the error.
	//always@(posedge clk)
//	begin
//		if (reset) begin
//			err_int_stat_reg	<= 1'b0; 		
//		end
//		else if (cmd_index == 6'h00) begin
//			err_int_stat_reg	<= 1'b0;
//		end
//		else if (cmd_index == 6'h08) begin	// for CMD8
//			err_int_stat_reg 	<= (rd_reg_input[15:8] == echo_bk_patt) ? 1'b0 : 1'b1;
//		end
//		else begin
//			err_int_stat_reg	<= 1'b0;
//		end
//	end						 

	//-------------------------------------------------------------------------
	// We need a x clocks counter.  It takes 1 clock to get a reading for the
	// memory map from the host controller.  However, we'll use x clocks
	// to give it some room.  We also use this counter if we have two writes in
	// the row so we can have sometime in between.
	//-------------------------------------------------------------------------
	defparam readClksCntr.dw 	= 3;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam readClksCntr.max	= 3'h5;	
	//-------------------------------------------------------------------------
	CounterSeq readClksCntr(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_reg_strb || wr_reg_strb_reg),   	 	
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
		.start_strb(rd_reg_strb),   	 	
		.cntr(), 
		.strb(rd_to_strb) 
	);		  
	
	// State machine to finalize a command.
   parameter state_start  						= 16'b0000_0000_0000_0001;
   parameter state_cmd_compl_int  			= 16'b0000_0000_0000_0010;
   parameter state_rd_wait  					= 16'b0000_0000_0000_0100;
   parameter state_clr_cmd_compl_status 	= 16'b0000_0000_0000_1000;
   parameter state_wr_wait					 	= 16'b0000_0000_0001_0000;
   parameter state_get_response_data		= 16'b0000_0000_0010_0000;
   parameter state_rd_wait2 					= 16'b0000_0000_0100_0000;
   parameter state_wait_for_tf_compl_int 	= 16'b0000_0000_1000_0000;	
   parameter state_rd_wait3 					= 16'b0000_0001_0000_0000;
   parameter state_clr_tf_compl_status 	= 16'b0000_0010_0000_0000;
   parameter state_wr_wait2				 	= 16'b0000_0100_0000_0000;
   parameter state_chk_resp_dat 				= 16'b0000_1000_0000_0000;
   parameter state_rd_wait4 					= 16'b0001_0000_0000_0000;	  
   parameter state_no_err 						= 16'b0010_0000_0000_0000;
   parameter state_err 							= 16'b0100_0000_0000_0000;
   parameter state_end 							= 16'b1000_0000_0000_0000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [15:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         // Outputs
			rd_reg_index_reg 				<= 12'h000;
			wr_reg_strb_reg				<= 1'b0;
			wr_reg_index_reg 				<= 12'h000;
			wr_reg_output_reg				<= {32{1'b0}};
			reg_attr_reg					<= 3'h0;
			fin_a_cmd_proc_reg			<= 1'b0;
			fin_cmnd_strb_reg				<= 1'b0;
			rd_reg_strb						<= 1'b0;
			err_int_stat_reg				<= err_int_stat_reg; // keep previous error
      end
      else
         (* PARALLEL_CASE *) case (state)
				state_start : begin				// 16'b0000_0000_0000_0001
               if (fin_a_cmd_strb)
                  state 				<= state_cmd_compl_int;
               else if (!fin_a_cmd_strb)
                  state 				<= state_start;
               else
                  state 				<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					fin_a_cmd_proc_reg	<= 1'b0;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;
					err_int_stat_reg		<= 16'h0000;	// reset to 0
				end
            state_cmd_compl_int : begin			// 16'b0000_0000_0000_0010
               state 					<= state_rd_wait;
               // Outputs								
					// read normal int status register
					rd_reg_index_reg 		<= 12'h030; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b1;	 	// strobe to start waiting
					err_int_stat_reg		<= 16'h0000;
            end
            state_rd_wait : begin					// 16'b0000_0000_0000_0100
					// Wait until we get a command complete interrupt.	
					// We have to wait until we get a response from the
					// command we just sent, ie from the sd card.
               if (cmd_compl)
                  state 				<= state_clr_cmd_compl_status;		  
					// If time is up and we don't get a command complete
					// interrupt, get out of the state machine.	 
					// We will timeout after 1 second.
               else if (rd_to_strb && !cmd_compl)
                  state 				<= state_end;
					// If it's cmd0 then there is no response,
					// no need to wait.
               else if ((cmd_index == 6'h00) && (end_bit_det_strb && !end_bit_det_strb_z1))
                  state 				<= state_end; 
					// else wait here
               else
                  state 				<= state_rd_wait;
               // Outputs
					rd_reg_index_reg 		<= 12'h030; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;
					err_int_stat_reg		<= 16'h0000;
            end
            state_clr_cmd_compl_status : begin	// 16'b0000_0000_0000_1000
               state 					<= state_wr_wait;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg		<= {{16{1'b0}},{15{1'b0}},1'b1};
					reg_attr_reg			<= 3'h3; // RW1C
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;	
					err_int_stat_reg		<= 16'h0000;
            end
            state_wr_wait : begin					// 16'b0000_0000_0001_0000
               if (read_clks_tout)
                  state 				<= state_get_response_data;
               else if (!read_clks_tout)
                  state 				<= state_wr_wait;
               else
                  state 				<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg		<= {{16{1'b0}},{15{1'b0}},1'b1};
					reg_attr_reg			<= 3'h3; // RW1C
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;	
					err_int_stat_reg		<= 16'h0000;
            end
            state_get_response_data : begin	// 16'b0000_0000_0010_0000	
               state 					<= state_rd_wait2;
               // Outputs
					rd_reg_index_reg 		<= 12'h010; // Response register
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b1;	
					err_int_stat_reg		<= 16'h0000;				
            end
            state_rd_wait2 : begin				// 16'b0000_0000_0100_0000
					// if time is up and cmd_with_tf_compl_int is true
					// go to state_wait_for_tf_compl_int.
               if (read_clks_tout && cmd_with_tf_compl_int)
                  state 				<= state_wait_for_tf_compl_int;
					// wait until time is up
               else if (!read_clks_tout)
                  state 				<= state_rd_wait2;
               else							
					// if time is up and cmd_with_tf_compl_int is false
					// go to state_chk_resp_dat.
                  state 				<= state_chk_resp_dat;
               // Outputs
					rd_reg_index_reg 		<= 12'h010; // Response register
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;
					err_int_stat_reg		<= 16'h0000;					
            end
            state_wait_for_tf_compl_int : begin	// 16'b0000_0000_1000_0000  
               state 					<= state_rd_wait3;
               // Outputs
					rd_reg_index_reg 		<= 12'h030; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b1;
					err_int_stat_reg		<= 16'h0000;
            end
            state_rd_wait3 : begin					// 16'b0000_0001_0000_0000
               if (read_clks_tout && tf_compl)
                  state 				<= state_clr_tf_compl_status;
               else if (!read_clks_tout)
                  state 				<= state_rd_wait3;
               else
                  state 				<= state_end;
               // Outputs
					rd_reg_index_reg 		<= 12'h030; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;
					err_int_stat_reg		<= 16'h0000;
            end
            state_clr_tf_compl_status : begin	// 16'b0000_0010_0000_0000 
               state 					<= state_wr_wait2;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg		<= {{16{1'b0}},{14{1'b0}},1'b1,1'b0};
					reg_attr_reg			<= 3'h3; // RW1C
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;	
					err_int_stat_reg		<= 16'h0000;
            end
            state_wr_wait2 : begin					// 16'b0000_0100_0000_0000
               if (read_clks_tout)
                  state 				<= state_chk_resp_dat;
               else if (!read_clks_tout)
                  state 				<= state_wr_wait2;
               else
                  state 				<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg		<= {{16{1'b0}},{14{1'b0}},1'b1,1'b0};
					reg_attr_reg			<= 3'h3; // RW1C
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;	
					err_int_stat_reg		<= 16'h0000;
            end
            state_chk_resp_dat : begin				// 16'b0000_1000_0000_0000
					state 					<= state_rd_wait4;
               // Outputs							  
					// Read the Error Interrupt Status Register
					rd_reg_index_reg 		<= 12'h032; // EIS register
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b1;	
					err_int_stat_reg		<= 16'h0000;				
            end
            state_rd_wait4 : begin					// 16'b0001_0000_0000_0000 									  
               if (read_clks_tout && (!err))
                  state 				<= state_no_err;	  									  
               else if (read_clks_tout && err)
                  state 				<= state_err;
               else if (!read_clks_tout)
                  state 				<= state_rd_wait4;
               else
                  state 				<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h032; 
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;	
					err_int_stat_reg		<= 16'h0000;				
            end										
            state_no_err : begin						// 16'b0010_0000_0000_0000
               state 					<= state_start;
					// Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					// will be reset to zero when go to state_start
					// and create a strobe.
					fin_cmnd_strb_reg		<= 1'b1;
					rd_reg_strb				<= 1'b0; 
					err_int_stat_reg		<= 16'h0000;
            end            							
            state_err : begin							// 16'b0100_0000_0000_0000
               state 					<= state_start;
					// Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					// will be reset to zero when go to state_start
					// and create a strobe.
					fin_cmnd_strb_reg		<= 1'b1;
					rd_reg_strb				<= 1'b0; 
					err_int_stat_reg		<= rd_reg_input[15:0];
            end            
            state_end : begin							// 16'b1000_0000_0000_0000
               state 					<= state_start;
					// Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b1;
					// will be reset to zero when go to state_start
					// and create a strobe.
					fin_cmnd_strb_reg		<= 1'b1;
					rd_reg_strb				<= 1'b0;
					err_int_stat_reg		<= err_int_stat_reg; 
            end            
            default: begin  // Fault Recovery
               state 					<= state_start;
               // Outputs
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					fin_a_cmd_proc_reg	<= 1'b0;
					fin_cmnd_strb_reg		<= 1'b0;
					rd_reg_strb				<= 1'b0;
					err_int_stat_reg		<= 1'b0;
				end
			endcase

endmodule
