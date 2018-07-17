`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:02:32 11/14/2012 
// Design Name: 
// Module Name:    sdc_detection 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 	When the Host Controller has detected a change in the 
//						card detect signal, it will notify this module to
//         			clear either the inserted or removed bit of the
//						Normal Interrupt Status Register 0x030.  It would also
//						turn on the power and clock to the SD Card if it detects
//						insertion.  If it is a removal, it will end all SD Card
//						processes.
//						For now, we'll enable the interrupts when we reset the PUC.
//						(1) To enable interrupt for card detection, write 1 to the 
//						following bits:
//						Card Insertion Status Enable in the Normal Interrupt Status 
//						Enable register
//						Card Insertion Signal Enable in the Normal Interrupt Signal 
//						Enable register
//						Card Removal Status Enable in the Normal Interrupt Status 
//						Enable register
//						Card Removal Signal Enable in the Normal Interrupt Signal 
//						Enable register
//						(2) When the Host Driver detects the card insertion or 
//						removal, clear its interrupt statuses.  If Card Insertion 
//						interrupt is generated, write 1 to Card Insertion in the 
//						Normal Interrupt Status	register. If Card Removal interrupt 
//						is generated, write 1 to Card Removal in the Normal Interrupt
//						Status register.
//						(3) Check Card Inserted in the Present State register. 
//						In the case where Card Inserted is 1, the Host
//						Driver can supply the power and the clock to the SD card. 
//						In the case where Card Inserted is 0, the other executing  
//						processes of the Host Driver shall be immediately closed.
//						This bit doesn't turn on the clock or power, it just
//						tells whether we can use the CLK or DAT lines or not.
//						Yes if it is one and no if it is zero.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sdc_detection(
	input 				clk,
   input 				reset,
	// card has been inserted and stabilized
	input					card_inserted_strb, 	
	// card has been removed and stabilized
	input					card_removed_strb,	
	// For the Host Controller memory map
	output	[11:0]	rd_reg_index,
	input 	[127:0]	rd_reg_input,
	output				wr_reg_strb,
	output	[11:0]	wr_reg_index,
	output 	[31:0]	wr_reg_output,
	output 	[2:0]		reg_attr,
	
	// notify that the card has been inserted or removed, active high.
	output				card_inserted, 
	output				sdc_det // indicates that we are in this module still
   );

	// Registers
	// check to see if card is inserted from Present State register.
	// 1 is inserted, 0 is removed
	reg			card_insrt_chk; 		
	reg			card_inserted_reg; // notify that the card has been inserted.
	reg			card_stat; // decide by card_inserted_strb or card_removed_strb
	// for host controller memory map
	reg 			wr_reg_strb_reg;
	reg [11:0] 	wr_reg_index_reg;
	reg [31:0]	wr_reg_output_reg;
	reg [11:0] 	rd_reg_index_reg;
	reg [2:0]	reg_attr_reg;

	// need 1 clock to get back reading from host controller
	reg			rd_reg_strb; 
	reg 			sdc_det_reg;
	
	// Wires
	wire			fin_2secs_strb;
	wire	[2:0]	seq_cntr;
	wire			fin_ints_strb;
	wire			three_clks_tout; // time to read the read back
	
	// Initialize sequential logic
	initial			
	begin
		card_insrt_chk			<= 1'b0;
		card_inserted_reg		<= 1'b0;
		card_stat				<= 1'b0;
		wr_reg_strb_reg		<= 1'b0;
		wr_reg_index_reg		<= 12'h000;
		wr_reg_output_reg		<= 32'h00000000;
		rd_reg_index_reg		<= 12'h000;
		reg_attr_reg			<= 3'h0;
		sdc_det_reg				<= 1'b0;
		rd_reg_strb				<= 1'b0;
	end
	
	// Assign registers to outputs.
	assign card_inserted		= card_inserted_reg;
	assign wr_reg_strb 		= wr_reg_strb_reg;
	assign wr_reg_index		= wr_reg_index_reg;
	assign wr_reg_output		= wr_reg_output_reg;
	assign rd_reg_index		= rd_reg_index_reg;
	assign reg_attr			= reg_attr_reg;
	assign sdc_det				= sdc_det_reg;
	
	
	// Set the card_stat flag whether the card is inserted
	// or removed.  What if the card is already there when
	// the power is turned on.  What do we do at reset?
	// What happened when we cycle the power and the card
	// was still there?
	always@(posedge clk)
	begin
		if (reset) begin
			card_stat	<= 1'b0; 
		end		
		else if (card_inserted_strb) begin 
			card_stat	<= 1'b1;
		end
		else if (card_removed_strb) begin 
			card_stat	<= 1'b0;
		end
		else begin
			card_stat	<= card_stat;
		end
	end
	
	// Becareful, other registers are written to 
	// rd_reg_input.  From Present State register (024h).
	// 1 means inserted, 0 means removed
	always@(posedge clk)
	begin
		if (reset) begin
			card_insrt_chk	<= 1'b0; 		
		end
		else begin
			card_insrt_chk	<= rd_reg_input[16];
		end
	end

	//-------------------------------------------------------------------------
	// We need a 3 clocks counter.  It takes 1 clock to get a reading for the
	// memory map from the host controller.  However, we'll use 3 clocks
	// to give it some room.
	//-------------------------------------------------------------------------
	defparam threeClksCntr_u1.dw 	= 2;
	// Change this to reflect the number of counts you want.
	// Count up to this number, starting at zero.
	defparam threeClksCntr_u1.max	= 2'h2;	
	//-------------------------------------------------------------------------
	CounterSeq threeClksCntr_u1(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(rd_reg_strb),   	 	
		.cntr(/*oneSecToutCnt*/), 
		.strb(three_clks_tout) 
	);
			
	// State machine for Card Detection
   parameter state_start 						= 7'b0000001;
   parameter state_clr_crd_insrt_int_stat	= 7'b0000010;
	// clr crd removal interrupt status
	parameter state_clr_crd_remv_int_stat	= 7'b0000100;
	// Check to see whether we are inserting or revoving the card.
   parameter state_chk_crd_insrt 			= 7'b0001000;
	// If the card is inserted, supply power and clock to the SD card.
	parameter state_supply_pwr		 			= 7'b0010000;
	// If the card is removed, shut down all processes in the host driver.
	parameter state_close_proc					= 7'b0100000;
	parameter state_end 							= 7'b1000000;

   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [6:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         //<outputs> <= <initial_values>;
			rd_reg_index_reg 				<= 12'h000;
			wr_reg_strb_reg				<= 1'b0;
			wr_reg_index_reg 				<= 12'h000;
			wr_reg_output_reg				<= {32{1'b0}};
			reg_attr_reg					<= 3'h0; 
			card_inserted_reg				<= 1'b0;
			rd_reg_strb						<= 1'b0;
			sdc_det_reg						<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)
				// Card detect, whether inserted or removed.
            state_start : begin 	// 7'b000 0001
					if (card_inserted_strb)
						state 				<= state_clr_crd_insrt_int_stat;
					else if (card_removed_strb)
						state 				<= state_clr_crd_remv_int_stat;	
					else if (!card_inserted_strb | !card_removed_strb)
						state 				<= state_start;
					else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_index_reg 		<= 12'h000;
					reg_attr_reg			<= 3'h0; 
					// what if the power is cycled and
					// the card was alread inserted?
					card_inserted_reg		<= card_inserted_reg;
					rd_reg_strb				<= 1'b0; 
					sdc_det_reg				<= 1'b0;
            end
            state_clr_crd_insrt_int_stat : begin // 7'b000 0010;
					state 					<= state_chk_crd_insrt;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= 12'h030;	// norm int. stat. reg.
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg		<= {{16{1'b0}},{9{1'b0}},1'b1,{6{1'b0}}};
					reg_attr_reg			<= 3'h3; // RW1C
					card_inserted_reg		<= card_inserted_reg;
					rd_reg_strb				<= 1'b1; // create strobe to wait for read
					sdc_det_reg				<= 1'b1;
				end
            state_clr_crd_remv_int_stat : begin // 7'b000 0100
					state 					<= state_chk_crd_insrt;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b1;
					wr_reg_index_reg 		<= 12'h030;
					// write 1 to clear, 0 to leave unchanged
					wr_reg_output_reg		<= {{16{1'b0}},{8{1'b0}},1'b1,{7{1'b0}}};
					reg_attr_reg			<= 3'h3; // RW1C
					card_inserted_reg		<= card_inserted_reg;
					rd_reg_strb				<= 1'b1; // create strobe to wait for read
					sdc_det_reg				<= 1'b1;
            end
            state_chk_crd_insrt : begin  // 7'b000 1000
					// wait for three clocks, if card is inserted 
					// go to supply power state.
					if (card_insrt_chk && three_clks_tout) 
                  state 				<= state_supply_pwr;	
					// wait for three clocks, if card is removed 
					// go to close process state.
               else if (!card_insrt_chk && three_clks_tout)
                  state 				<= state_close_proc;
               else if (!three_clks_tout) // if time is not up, wait here
                  state 				<= state_chk_crd_insrt;
               else
                  state 				<= state_end;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h024; // Present State Reg.
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					card_inserted_reg		<= card_inserted_reg;
					rd_reg_strb				<= 1'b0;
					sdc_det_reg				<= 1'b1;
            end									 
            state_supply_pwr : begin // 7'b001 0000
					state 					<= state_end;
               //<outputs> <= <values>;
					// The card has been inserted.
					// We'll supply code for this process when we know
					// more about powering to the sd card.
					// If card inserted bit is set in the Present State reg,
					// we'll set a flag to allow sd clock and power
					// to be on.  Look at 2.2.11 Power Control Register (029h).
					// Not supported at the moment.
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					card_inserted_reg		<= 1'b1;	// latch card inserted
					rd_reg_strb				<= 1'b0;
					sdc_det_reg				<= 1'b1;
				end
            state_close_proc : begin  // 7'b010 0000
					state 					<= state_end;
               //<outputs> <= <values>;
					// The card has been removed
					// We'll supply code for this process when we know
					// what we need to do to end sd card processes.
					// Look at 2.2.11 Power Control Register (029h).			  
					// Not supported at the moment.
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					card_inserted_reg		<= 1'b0;	// latch card removed
					rd_reg_strb				<= 1'b0;
					sdc_det_reg				<= 1'b1;
            end
				state_end : begin 		// 7'b100 0000
					state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					card_inserted_reg		<= card_inserted_reg;
					rd_reg_strb				<= 1'b0;
					sdc_det_reg				<= 1'b0;
            end
				default: begin  // Fault Recovery
               state 					<= state_start;
               //<outputs> <= <values>;
					rd_reg_index_reg 		<= 12'h000;
					wr_reg_strb_reg		<= 1'b0;
					wr_reg_index_reg 		<= 12'h000;
					wr_reg_output_reg		<= {32{1'b0}};
					reg_attr_reg			<= 3'h0; 
					card_inserted_reg		<= card_inserted_reg;
					rd_reg_strb				<= 1'b0;
					sdc_det_reg				<= 1'b0;
				end
         endcase
													
	
endmodule