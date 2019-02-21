`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    13:05:35 07/10/2013 
// Design Name: 
// Module Name:    enb_interupt 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: This module enables the interrupt when it is strobed.
//                      Let the PUC or other hosts set how many interrupts.
//
//////////////////////////////////////////////////////////////////////////////////
module enb_interupt(
   input 				clk,
   input 				reset,
   input 				enb_int_strb,
	input 	[11:0] 	enb_addr, 	// memory map address
	input 	[15:0]	enb_data, 	// memory map data
	// For the Host Controller memory map
//   output	[11:0]	rd_reg_index,
//	input 	[127:0]	rd_reg_input,
	output				wr_reg_strb,
	output	[11:0]	wr_reg_index,
	output 	[31:0]	wr_reg_output,
	output 	[2:0]		reg_attr,
	output				enb_int_proc // indicates that we are in this module still
);

	// Registers 		
	reg 			wr_reg_strb_reg;
	reg [11:0] 	wr_reg_index_reg;
	reg [31:0]	wr_reg_output_reg;
	reg [2:0]	reg_attr_reg;
	reg 			enb_int_proc_reg;

	// Wires
	
	// Initialize sequential logic
	initial			
	begin
		wr_reg_strb_reg		<= 1'b0;
		wr_reg_index_reg		<= 12'h000;
		wr_reg_output_reg		<= 32'h00000000;
		reg_attr_reg			<= 3'h0;
		enb_int_proc_reg		<= 1'b0;
	end
	
	// Assign wires or registers (need to check) to outputs.
	assign wr_reg_strb 		= wr_reg_strb_reg;
	assign wr_reg_index		= wr_reg_index_reg;
	assign wr_reg_output		= wr_reg_output_reg;
	assign reg_attr			= reg_attr_reg;
	assign enb_int_proc		= enb_int_proc_reg;

	// State machine for writing enable interrupt
   parameter ste_strt 		= 4'b0001;
   parameter ste_enb_int 	= 4'b0010;
   parameter ste_buffr 		= 4'b0100;
   parameter ste_end 		= 4'b1000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="ste_strt" *) 
	reg [3:0] state = ste_strt;

   always@(posedge clk)
      if (reset) begin
         state 					<= ste_strt;
         //<outputs> <= <initial_values>;
			wr_reg_strb_reg		<= 1'b0;
			wr_reg_index_reg 		<= 12'h000;
			wr_reg_output_reg		<= {32{1'b0}};
			reg_attr_reg			<= 3'h0;
			enb_int_proc_reg		<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
            ste_strt : begin
               if (enb_int_strb)
                  state <= ste_enb_int;
               else
                  state <= ste_strt;
               //<outputs> <= <values>;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					enb_int_proc_reg		<= 1'b0;
            end
            ste_enb_int : begin
               state <= ste_buffr;
               //<outputs> <= <values>;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= enb_addr;
					wr_reg_output_reg		<= {{16{1'b0}},enb_data};
					reg_attr_reg			<= 3'h0;
					enb_int_proc_reg		<= 1'b1;
            end
            ste_buffr : begin
               state <= ste_end;
               //<outputs> <= <values>;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					enb_int_proc_reg		<= 1'b1;
            end
            ste_end : begin
               state <= ste_strt;
               //<outputs> <= <values>;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					enb_int_proc_reg		<= 1'b1;
            end
            default: begin  // Fault Recovery
               state <= ste_strt;
               //<outputs> <= <values>;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0;
					enb_int_proc_reg		<= 1'b0;
	    end
         endcase
							

endmodule
