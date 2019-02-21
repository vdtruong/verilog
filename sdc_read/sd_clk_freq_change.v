`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:32:05 12/03/2012 
// Design Name: 
// Module Name:    sd_clk_freq_change 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 	3.2.3 SD Clock Frequency Change Sequence
//						The sequence for changing SD Clock frequency is shown in 
//						Figure 3-5. When SD Clock is still off,
//						step (1) is omitted. Please refer to Section 3.2.2 for 
//						details regarding step (1) and Section 3.2.1 for
//						step (2).
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module sd_clk_freq_change(
   input 				clk,
   input 				reset,
   input 				sd_clk_freq_chng_strb, 	// starts this module s.m.
	input 	[19:0] 	req_clk,						// requested clock frequency	

	// For the Host Controller memory map
	output	[11:0]	rd_reg_index,
	input 	[127:0]	rd_reg_input,
	output				wr_reg_strb,
	output	[11:0]	wr_reg_index,
	output 	[31:0]	wr_reg_output,
	output 	[2:0]		reg_attr
   );

	// Registers.
	reg [11:0] 	rd_reg_index_reg;
	reg 			wr_reg_strb_reg;
	reg [11:0] 	wr_reg_index_reg;
	reg [31:0]	wr_reg_output_reg;
	reg [2:0]	reg_attr_reg;
	
	reg [11:0] 	rd_reg_index_int;
	reg 			wr_reg_strb_int;
	reg [11:0] 	wr_reg_index_int;
	reg [31:0]	wr_reg_output_int;
	reg [2:0]	reg_attr_int;
	reg			sd_clk_on;
	reg			stop_sd_clk_strb;
	reg			calc_clk_strb;
//	reg			set_sd_clk_freq_chg;
//	reg			set_sd_clk_stop;
//	reg			set_sd_clk_supply;
	
	// Wires
	wire			sd_clk_off;
	wire [11:0]	rd_reg_index_clk_stop;
	wire 			wr_reg_strb_clk_stop;
	wire [11:0]	wr_reg_index_clk_stop;
	wire [31:0]	wr_reg_output_clk_stop;
	wire [2:0]	reg_attr_clk_stop;
	wire [11:0]	rd_reg_index_clk_sup;
	wire			wr_reg_strb_clk_sup;
	wire [11:0]	wr_reg_index_clk_sup;
	wire [31:0]	wr_reg_output_clk_sup;
	wire [2:0]	reg_attr_clk_sup;
	
	// Initialize sequential logic
	initial			
	begin
		rd_reg_index_reg		<= 12'h000;
		wr_reg_strb_reg		<= 1'b0;
		wr_reg_index_reg		<= 12'h000;
		wr_reg_output_reg		<= 32'h00000000;
		reg_attr_reg			<= 3'h0;
		
		rd_reg_index_int		<= 12'h000;
		wr_reg_strb_int		<= 1'b0;
		wr_reg_index_int		<= 12'h000;
		wr_reg_output_int		<= 32'h00000000;
		reg_attr_int			<= 3'h0;
		sd_clk_on				<= 1'b0;
		stop_sd_clk_strb		<= 1'b0;
		calc_clk_strb			<= 1'b0;
//		set_sd_clk_freq_chg	<= 1'b0;
//		set_sd_clk_stop		<= 1'b0;
//		set_sd_clk_supply		<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign rd_reg_index		= rd_reg_index_reg;
	assign wr_reg_strb 		= wr_reg_strb_reg;
	assign wr_reg_index		= wr_reg_index_reg;
	assign wr_reg_output		= wr_reg_output_reg;
	assign reg_attr			= reg_attr_reg;
	
	// Set the rd_reg_index output.
	always@(posedge clk)
	begin
		if (reset) begin
			rd_reg_index_reg	<= 12'h000; 		
		end
		else if (stop_sd_clk_strb) begin
			rd_reg_index_reg	<= rd_reg_index_clk_stop;
		end
		else if (calc_clk_strb) begin
			rd_reg_index_reg	<= rd_reg_index_clk_sup;
		end
		else begin
			rd_reg_index_reg	<= rd_reg_index_int;
		end
	end
	
	// Set the wr_reg_strb output.
	always@(posedge clk)
	begin
		if (reset) begin
			wr_reg_strb_reg	<= 1'b0; 		
		end
		else if (stop_sd_clk_strb) begin
			wr_reg_strb_reg	<= wr_reg_strb_clk_stop;
		end
		else if (calc_clk_strb) begin
			wr_reg_strb_reg	<= wr_reg_strb_clk_sup;
		end
		else begin
			wr_reg_strb_reg	<= wr_reg_strb_int;
		end
	end
	
	// Set the wr_reg_index output.
	always@(posedge clk)
	begin
		if (reset) begin
			wr_reg_index_reg	<= 12'h000; 		
		end
		else if (stop_sd_clk_strb) begin
			wr_reg_index_reg	<= wr_reg_index_clk_stop;
		end
		else if (calc_clk_strb) begin
			wr_reg_index_reg	<= wr_reg_index_clk_sup;
		end
		else begin
			wr_reg_index_reg	<= wr_reg_index_int;
		end
	end
	
	// Set the wr_reg_output output.
	always@(posedge clk)
	begin
		if (reset) begin
			wr_reg_output_reg	<= 32'h00000000; 		
		end
		else if (stop_sd_clk_strb) begin
			wr_reg_output_reg	<= wr_reg_output_clk_stop;
		end
		else if (calc_clk_strb) begin
			wr_reg_output_reg	<= wr_reg_output_clk_sup;
		end
		else begin
			wr_reg_output_reg	<= wr_reg_output_int;
		end
	end
	
	// Set the reg_attr output.
	always@(posedge clk)
	begin
		if (reset) begin
			reg_attr_reg	<= 3'h0; 		
		end
		else if (stop_sd_clk_strb) begin
			reg_attr_reg	<= reg_attr_clk_stop;
		end
		else if (calc_clk_strb) begin
			reg_attr_reg	<= reg_attr_clk_sup;
		end
		else begin
			reg_attr_reg	<= reg_attr_int;
		end
	end
	
	// Check to see if the sd clock is still on.
	always@(posedge clk)
	begin
		if (reset) begin
			sd_clk_on	<= 1'b0; 		
		end
		else begin
			// 2.2.14 Clock Control Register (Offset 02Ch)
			// The host driver controls this bit.
			// The host controller uses this bit to turn
			// on or off the clock.
			sd_clk_on	<= rd_reg_input[2];
		end
	end

	// State machine for sd clock frequency change.
   parameter state_start 			= 4'b0001;
   parameter state_sd_clk_stop	= 4'b0010;
   parameter state_sd_clk_supply	= 4'b0100;
   parameter state_end 				= 4'b1000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [3:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         //<outputs> <= <initial_values>;
			rd_reg_index_int 				<= 12'h000;
			wr_reg_strb_int				<= 1'b0;
			wr_reg_index_int 				<= 12'h000;
			wr_reg_output_int				<= {32{1'b0}};
			reg_attr_int					<= 3'h0;
			stop_sd_clk_strb				<= 1'b0;
			calc_clk_strb					<= 1'b0;
//			set_sd_clk_freq_chg			<= 1'b0;
//			set_sd_clk_stop				<= 1'b0;
//			set_sd_clk_supply				<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
            state_start : begin
               if (sd_clk_on && sd_clk_freq_chng_strb)
                  state 				<= state_sd_clk_stop;
               else if (!sd_clk_on && sd_clk_freq_chng_strb)
                  state 				<= state_sd_clk_supply;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					// 2.2.14 Clock Control Register (Offset 02Ch)
					// If the sd clock is still off we can change
					// the frequency right away.  We don't have to
					// turn it off first.
					rd_reg_index_int 		<= 12'h02C; 
					wr_reg_strb_int		<= 1'b0;
					wr_reg_index_int 		<= 12'h000;
					wr_reg_output_int		<= {32{1'b0}};
					reg_attr_int			<= 3'h0;
					stop_sd_clk_strb		<= 1'b0;
					calc_clk_strb			<= 1'b0;
//					set_sd_clk_freq_chg	<= 1'b1;
//					set_sd_clk_stop		<= 1'b0;
//					set_sd_clk_supply		<= 1'b0;					
            end
            state_sd_clk_stop : begin
               if (sd_clk_off)
                  state 				<= state_sd_clk_supply;
               else if (!sd_clk_off)
                  state 				<= state_sd_clk_stop;
					// May need to write code to escape this state
					// if the sd clock is never turned off.
					// Could use a counter to time out the wait.
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_int 		<= 12'h000; 
					wr_reg_strb_int		<= 1'b0;
					wr_reg_index_int 		<= 12'h000;
					wr_reg_output_int		<= {32{1'b0}};
					reg_attr_int			<= 3'h0;
					stop_sd_clk_strb		<= 1'b1; // activate sd clock stop sequence
					calc_clk_strb			<= 1'b0;
//					set_sd_clk_freq_chg	<= 1'b0;
//					set_sd_clk_stop		<= 1'b1;
//					set_sd_clk_supply		<= 1'b0;
            end
            state_sd_clk_supply : begin
					state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_int		<= 12'h000;
					wr_reg_strb_int		<= 1'b0;
					wr_reg_index_int		<= 12'h000;
					wr_reg_output_int		<= {32{1'b0}};
					reg_attr_int			<= 3'h0;
					stop_sd_clk_strb		<= 1'b0;
					calc_clk_strb			<= 1'b1; // activate the sd clock supply
//					set_sd_clk_freq_chg	<= 1'b0;
//					set_sd_clk_stop		<= 1'b0;
//					set_sd_clk_supply		<= 1'b1;
            end
            state_end : begin
					state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_int		<= 12'h000;
					wr_reg_strb_int		<= 1'b0;
					wr_reg_index_int		<= 12'h000;
					wr_reg_output_int		<= {32{1'b0}};
					reg_attr_int			<= 3'h0;
					stop_sd_clk_strb		<= 1'b0;
					calc_clk_strb			<= 1'b0;
//					set_sd_clk_freq_chg	<= 1'b0;
//					set_sd_clk_stop		<= 1'b0;
//					set_sd_clk_supply		<= 1'b0;
				end
            default: begin  // Fault Recovery
               state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_int		<= 12'h000;
					wr_reg_strb_int		<= 1'b0;
					wr_reg_index_int		<= 12'h000;
					wr_reg_output_int		<= {32{1'b0}};
					reg_attr_int			<= 3'h0;
					stop_sd_clk_strb		<= 1'b0;
					calc_clk_strb			<= 1'b0;
//					set_sd_clk_freq_chg	<= 1'b0;
//					set_sd_clk_stop		<= 1'b0;
//					set_sd_clk_supply		<= 1'b0;
				end
         endcase

	// Instantiate the module
	sd_clk_stop sd_clk_stop_u1 (
		.clk(clk), 
		.reset(reset), 
		.stop_sd_clk_strb(stop_sd_clk_strb),
		 
		// For the Host Controller memory map	
		.rd_reg_index(rd_reg_index_clk_stop), 
		.rd_reg_input(rd_reg_input), 
		.wr_reg_strb(wr_reg_strb_clk_stop), 
		.wr_reg_index(wr_reg_index_clk_stop), 
		.wr_reg_output(wr_reg_output_clk_stop), 
		.reg_attr(reg_attr_clk_stop),
		 
		.sd_clk_off_suc(sd_clk_off_suc),
		.fin_stp_clk(fin_stp_clk),
		.sd_clk_stop_proc(sd_clk_stop_proc)
		);
	
	// Instantiate the module
	sd_clk_sup sd_clk_sup_u2 (
		.clk(clk), 
		.reset(reset), 
		.calc_clk_strb(calc_clk_strb), 
		.req_clk(req_clk),				
		.dat_tf_mode(1'b1),
		 
		// For the Host Controller memory map
		.rd_reg_index(rd_reg_index_clk_sup), 
		.rd_reg_input(rd_reg_input), 
		.wr_reg_strb(wr_reg_strb_clk_sup), 
		.wr_reg_index(wr_reg_index_clk_sup), 
		.wr_reg_output(wr_reg_output_clk_sup), 
		.reg_attr(reg_attr_clk_sup),
		 
		.sd_clk_enb_strb(),	  // sd clock is ready to be used
		.sd_clk_proc()		  // indicates that we are in this module
	);	 																				  

endmodule
