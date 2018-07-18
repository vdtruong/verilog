`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company:          Fresenius NA
// Engineer: 		   VDT
// 
// Create Date:      10:36:56 10/03/2012 
// Design Name: 
// Module Name:      sd_host_controller 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 	   This is the SD Host Controller.  It interacts with the
//						   SD Card and the Host Bus Driver.  The Host Bus Driver
//						   interacts with the PUC.
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
///////////////////////////////////////////////////////////////////////////////
module sd_host_controller(
	input 					clk,
	input						reset,																 
	input 					card_inserted_strb,
	input 					card_removed_strb,
	
	// For communication with the map registers.
	input 		[11:0]	rd_reg_index, 	      // which reg to read
	output reg	[127:0]	rd_reg_output,	      // export reg data	
	input						wr_reg_strb,	      // strobe to write data
	input 		[11:0]	wr_reg_index,	      // which reg to write
	input 		[31:0]	wr_reg_input,	      // data to write
	input 		[2:0]		reg_attr,
	input 		[2:0]		kind_of_resp, 	      // based on command index
																									 
   input 		[35:0] 	data,	  															 
	
	// For adma state machine.
	input						strt_adma_strb,	   // Start Fifo transfer to sd card.	   	
	input			[15:0]	pkt_crc,					// CRC for 512 bytes from PUC.   
   output               des_fifo_rd_strb,    // strobe for the descriptor item   
   input       [63:0]   des_rd_data,         // descriptor item   
   input                fin_cmnd_strb,       // finished sending out cmd13, response is ready   input  
	
	// For Fifo data.									
	// Send signal to puc to start filling up fifo.
	//output					strt_fifo_strb,
   // This signal fetches the first data from the data bram.
   output reg           strt_snd_data_strb,  // start to send data to sd card.
   // The signal fetches the following data from the bram
   // until we are finished with one block of data.  One block
   // is 64 words of 64 bits each.
   output 					new_dat_strb,			// Ready for next word of data to sd card.
	input 		[63:0]	sm_rd_data,				// from the system memory RAM	 
	input						fifo_rdy_strb,			// fifo is ready to be used
	
	output					end_bit_det_strb,		// finished sending out command
	output					r1_crc7_good_out,
   output               snd_auto_cmd12_strb, // send the auto cmd12 to end multiple blocks transfer
   //output               issue_abort_cmd,     // indicate an abort command is being sent
   output               snd_cmd13_strb,      // send cmd13 to poll for card ready    
	
	input						D0_in, 					// only D0 has a busy signal
	output					D0_out,
	input						D1_in, 
	output					D1_out,
	input						D2_in,	 
	output					D2_out,
	input						D3_in,	 
	output					D3_out,
	output     				SDC_CLK,
	input						cmd_in,
	output					cmd_out
   );

/*-----------------------------------------------------------------------
	SD Specifications
	Part A2
	SD Host Controller
	Simplified Specification
	Version 3.00
	February 25, 2011
	
                          Table 2-1 : SD Host Controller Register Map
								  The SD Host Controller or the Host Bus Driver
								  can both write and read to these registers.  It
								  depends on the situation.
	Offset 	
	000h SDMA System Address (Low)
		  Argument 2 (Low)
	002h SDMA System Address (High)
		  Argument 2 (High)
	004h Block Size
	006h Block Count
	008h Argument 1 (Low)
	00Ah Argument 1 (High)
	00Ch Transfer Mode
	00Eh Command
	010h Response0
	012h Response1
	014h Response2
	016h Response3
	018h Response4
	01Ah Response5
	01Ch Response6
	01Eh Response7
	020h Buffer Data Port0
	022h Buffer Data Port1
	024h Present State
	026h Present State
	028h Power Control Host Control 1
	02Ah Wakeup Control Block Gap Control
	02Ch Clock Control
	02Eh Software Reset Timeout Control
	030h Normal Interrupt Status
	032h Error Interrupt Status
	034h Normal Interrupt Status Enable
	036h Error Interrupt Status Enable
	038h Normal Interrupt Signal Enable
	03Ah Error Interrupt Signal Enable
	03Ch Auto CMD Error Status
	03Eh Host Control 2
	040h Capabilities
	042h Capabilities
	044h Capabilities
	046h Capabilities
	048h Maximum Current Capabilities
	04Ah Maximum Current Capabilities
	04Ch Maximum Current Capabilities (Reserved)
	04Eh Maximum Current Capabilities (Reserved)
	050h Force Event for Auto CMD Error Status
	052h Force Event for Error Interrupt Status
	054h --- ADMA Error Status
	058h ADMA System Address [15:00]
	05Ah ADMA System Address [31:16]
	05Ch ADMA System Address [47:32]
	05Eh ADMA System Address [63:48]
	060h Preset Value
	062h Preset Value
	064h Preset Value
	066h Preset Value
	068h Preset Value
	06Ah Preset Value
	06Ch Preset Value
	06Eh Preset Value
	0E0h Shared Bus Control (Low)
	0E2h Shared Bus Control (High)
	0FCh Slot Interrupt Status
	0FEh Host Controller Version
	-----------------------------------------------------------------------*/

	// 2.2.1 SDMA System Address / Argument 2 Register (Offset 000h)
	reg[31:0] sdma_system_addr;
	// 2.2.2 Block Size Register (Offset 004h)
	reg[15:0] block_size;
	// 2.2.3 Block Count Register (Offset 006h)
	reg[15:0] block_count;
	// 2.2.4 Argument 1 Register (Offset 008h)
	reg[31:0] argument_1;
	// 2.2.5 Transfer Mode Register (Offset 00Ch)
	reg[15:0] transfer_mode;
	// 2.2.6 Command Register (Offset 00Eh) (pg 40)
   // Whenever you write to this register, you will
   // generate a send to the sdc.
	reg[15:0] command;
	// 2.2.7 Response Register (Offset 010h)
	reg[127:0] response;
	// 2.2.8 Buffer Data Port Register (Offset 020h)
	reg[31:0] buffer_data;
	// 2.2.9 Present State Register (Offset 024h) (pg 44)
	reg[31:0] present_state;
	// 2.2.10 Host Control 1 Register (Offset 028h)
	reg[7:0]  host_cntrl_1;
	// 2.2.11 Power Control Register (Offset 029h)
	reg[7:0]  power_cntrl;
	// 2.2.12 Block Gap Control Register (Offset 02Ah)
	reg[7:0]  block_gap_cntrl;
	// 2.2.13 Wakeup Control Register (Offset 02Bh)
	reg[7:0]  wakeup_cntrl;
	// 2.2.14 Clock Control Register (Offset 02Ch)
	reg[15:0] clock_cntrl;
	// 2.2.15 Timeout Control Register (Offset 02Eh)
	reg[7:0]  timeout_cntrl;
	// 2.2.16 Software Reset Register (Offset 02Fh)
	reg[7:0]  software_reset;
	// 2.2.17 Normal Interrupt Status Register (Offset 030h) (pg 63)
	reg[15:0] normal_int_status;
	// 2.2.18 Error Interrupt Status Register (Offset 032h) (pg 68)
	reg[15:0] error_int_status;
	// 2.2.19 Normal Interrupt Status Enable Register (Offset 034h)
	reg[15:0] normal_int_status_enb;
	// 2.2.20 Error Interrupt Status Enable Register (Offset 036h)
	reg[15:0] error_int_status_enb;
	// 2.2.21 Normal Interrupt Signal Enable Register (Offset 038h)
	reg[15:0] normal_int_signal_enb;
	// 2.2.22 Error Interrupt Signal Enable Register (Offset 03Ah)
	reg[15:0] error_int_signal_enb;
	// 2.2.23 Auto CMD Error Status Register (Offset 03Ch)
	reg[15:0] auto_cmd_error_status;
	// 2.2.24 Host Control 2 Register (Offset 03Eh)
	reg[15:0] host_cntrl_2;
	// 2.2.25 Capabilities Register (Offset 040h)
	reg[63:0] capabilities;
	// 2.2.26 Maximum Current Capabilities Register (Offset 048h)
	reg[63:0] max_current_capabilities;
	// 2.2.27 Force Event Register for Auto CMD Error Status (Offset 050h)
	reg[15:0] fer_for_aces;
	// 2.2.28 Force Event Register for Error Interrupt Status (Offset 052h)
	reg[15:0] fer_for_eis;
	// 2.2.29 ADMA Error Status Register (Offset 054h)
	reg[7:0]  adm_error_status;
	// 2.2.30 ADMA System Address Register (Offset 058h)
   // Should be 64 bits but we are only using 32 bits.
	reg[31:0] adma_system_addr;
	// 2.2.31 Preset Value Registers (Offset 06F-060h)
	reg[15:0] preset_value;
	// 2.2.32 Shared Bus Control Register (Offset 0E0h) (Optional)
	// 2.2.33 Slot Interrupt Status Register (Offset 0FCh)
	reg[15:0] slot_int_status;
	// 2.2.34 Host Controller Version Register (Offset 0FEh)
	reg[15:0] host_controller_version;
	// End of map registers///////////////						  
	
	// Followings are not part of SD Host Controller register map.
	//  		CRC for DAT0 (Offset 0FFh)
	reg	[15:0] 	dat0_crc;
	reg				new_cmd_set_strb;			// start to build command
	reg				snd_cmd_strb;				// start to send the command							
	reg 	[127:0]	reg_selected;
	reg 	[63:0]	reg2_selected;
	reg	[31:0] 	present_state_z1;						
	reg   [15:0]   normal_int_status_z1;   // delay
	reg				wr_reg_strb_z1;			// strobe to write data, delay
	reg				wr_reg_strb_z2;			// strobe to write data, delay										  
	// This will start the ADMA2 base on the card status response packet.
	// Bit 8 of the Card Status packet tells us if the sd card is ready
	// to accept data.
	reg				strt_dat_tf; 
	reg				sd_clk_stab_reg;
	reg				sd_clk_stab_reg_z1;
	reg				resp_recvd; 		// response received flag	
	reg				cmd_indx_err;		// command index error	 	
	reg				cmd_crc_err;		// command crc error
	reg				new_resp_pkt_strb_z1;	// careful, based on sdc_clk
	reg				new_resp_pkt_strb_z2;	// careful, based on sdc_clk
	reg 				new_resp_2_pkt_strb_z1;	// careful, based on sdc_clk						
	reg				end_bit_det_strb_z1;		// careful, based on sdc_clk
	reg				post_r1_pkt_strb;	// create a post resp strobe
	reg				post_r2_pkt_strb;	// create a post resp2 strobe
	reg				r2_resp_enb;		// Determine if it's a R2 response.		
	reg	[15:0]	rca;					// RCA after reception of CMD3.		
	reg				wr_busy_z1; 		// indicates that the sd card is busy, delay
   reg            des_fifo_rd_strb_z1; // delay
   reg            des_fifo_rd_strb_z2; // delay
	reg            des_fifo_rd_strb_z3; // delay
	reg            des_fifo_rd_strb_z4; // delay
	reg            des_fifo_rd_strb_z5; // delay
	reg            des_fifo_rd_strb_z6; // delay
	// Reached the last descriptor table, 
	// attr_end_descr = 1.  We are done with all data blocks.
	// If the Auto CMD12 is set in the transfer mode register,
	// the host controller should send the CMD12 automatically
	// to stop the transfer.  This is done after the last block
	// has been sent/receive to/from the SD card.
	reg				end_descr;
   reg            dat_tf_done_z1;      // delay
	
	// Wires	  
	wire				new_cmd_strb; 
	wire	[47:0]	cmd_packet;		 
	wire				inserted_card_strb;
	wire				new_resp_pkt_strb;	// careful, based on sdc_clk
	wire 				new_resp_2_pkt_strb;	// careful, based on sdc_clk
	wire 	[47:0] 	response_packet;
	wire 	[135:0] 	r2_packet;
	wire	[6:0]		resp2_crc7_out;
	wire				adma_sar_inc_strb; 	      // increments adma sys. addr. reg.	
   wire           adma2_rdy_to_snd_dat_strb; // send first word of each block
						// careful, based on sdc_clk
	wire				end_bit_det_strb;		      // end bit of write command detected
	wire				wr_busy; 				      // indicates that the sd card is busy
	wire				new_dat_set_strb;       
	wire 	[71:0]	tf_data;					   	  								 	 	
	wire				dat_tf_done;			      // Finished with data transfer.
	wire				sd_clk_stable;
	wire				sdc_clk; 				   // internally generated sd clock.
	wire	[15:0]	dat_crc16_out;          
	wire				fin_64sdclks_strb; 	   // for Command Timeout Error	
	wire				fin_strtchStrb40h; 	   // finish the snd_cmd_strb latch
	wire				fin_strtchStrb10h; 	   // finish the snd_cmd_strb latch	
   wire 	[4095:0] rd0_pkt;						// read packet from sd card, single line 
	wire				new_rd0_pkt_strb;		   // rd0 pkt ready.
	
	// Initialize sequential logic
	// Need to put the registers in here too.
	initial			
	begin												
		reg_selected					<= {128{1'b0}};
		reg2_selected					<= {64{1'b0}};
		new_cmd_set_strb 				<= 1'b0;		  
		wr_reg_strb_z1 				<= 1'b0;		  
		wr_reg_strb_z2 				<= 1'b0;
		snd_cmd_strb 					<= 1'b0;
		strt_dat_tf						<= 1'b0;
		strt_snd_data_strb 			<= 1'b0;
		sd_clk_stab_reg				<= 1'b0;
		sd_clk_stab_reg_z1			<= 1'b0;
		resp_recvd 						<= 1'b0;	
		cmd_indx_err					<= 1'b0;	
		cmd_crc_err						<= 1'b0;	
		new_resp_pkt_strb_z1			<= 1'b0;	 
		new_resp_pkt_strb_z2			<= 1'b0;	
		new_resp_2_pkt_strb_z1		<= 1'b0;	
		r2_resp_enb						<= 1'b0;
		end_bit_det_strb_z1			<= 1'b0;	
		post_r1_pkt_strb				<= 1'b0;	
		post_r2_pkt_strb				<= 1'b0;
		rca								<= {16{1'b0}};			  
		dat0_crc							<= {16{1'b0}};			  
		wr_busy_z1						<= 1'b0;
		des_fifo_rd_strb_z1		   <= 1'b0; 
		des_fifo_rd_strb_z2		   <= 1'b0; 
		des_fifo_rd_strb_z3		   <= 1'b0; 
		des_fifo_rd_strb_z4			<= 1'b0; 
		des_fifo_rd_strb_z5			<= 1'b0; 
		des_fifo_rd_strb_z6			<= 1'b0;
		dat_tf_done_z1			      <= 1'b0;
      //snd_auto_cmd12_strb 	      <= 1'b0;
		
		// Begin of map register initializing.
		sdma_system_addr				<= {32{1'b0}};
		block_size						<= {16{1'b0}};
		block_count						<= {16{1'b0}};
		argument_1						<= {32{1'b0}};
		transfer_mode					<= {16{1'b0}};
		command							<= {16{1'b0}};
		response							<= {128{1'b0}};	
		buffer_data						<= {32{1'b0}};
		present_state 					<= {32{1'b0}};
		present_state_z1				<= {32{1'b0}};
		host_cntrl_1					<= {8{1'b0}};
		power_cntrl						<= {8{1'b0}};
		block_gap_cntrl				<= {8{1'b0}};
		wakeup_cntrl					<= {8{1'b0}};	
		clock_cntrl 					<= 16'h4001;
		timeout_cntrl 					<= {8{1'b0}}; 
		software_reset					<= {8{1'b0}};									 
		normal_int_status				<= {16{1'b0}};								 
		normal_int_status_z1			<= {16{1'b0}}; // delay
		error_int_status				<= {16{1'b0}};
		// Enable interrupts, should be set up by bus host driver
		// Maybe a separate application module can set this.
		normal_int_status_enb		<= 16'h01CB;  
		error_int_status_enb			<= 16'h01CB;
		normal_int_signal_enb		<= 16'h01CB;
		error_int_signal_enb			<= 16'h01CB;	
		auto_cmd_error_status		<= {16{1'b0}}; 
		host_cntrl_2					<= {16{1'b0}};
		// Base (maximum) clock frequency for the SD Clock
		// is 50 MHz.
		capabilities					<= {{44{1'b0}}, 4'h8, 8'h32, {8{1'b0}}};  
		max_current_capabilities	<= {64{1'b0}}; 
		fer_for_eis						<= {16{1'b0}}; 
		adm_error_status				<= {8{1'b0}};   
		adma_system_addr				<= {32{1'b0}}; 
		preset_value					<= {16{1'b0}}; 
		slot_int_status				<= {16{1'b0}}; 
		host_controller_version		<= {16{1'b0}};
		// End of map register initializing.
	end																
	
	// Set up delays.
	always@(posedge clk)
	begin
		if (reset) begin							
			sd_clk_stab_reg_z1		<= 1'b0;
			new_resp_pkt_strb_z1		<= 1'b0;
			new_resp_pkt_strb_z2		<= 1'b0;
			new_resp_2_pkt_strb_z1	<= 1'b0;	
			end_bit_det_strb_z1		<= 1'b0;	 
			present_state_z1			<= {32{1'b0}};	
			normal_int_status_z1	   <= {16{1'b0}};	
			wr_reg_strb_z1				<= 1'b0;		 	  	
			wr_reg_strb_z2				<= 1'b0;				  
			wr_busy_z1					<= 1'b0;
			des_fifo_rd_strb_z1	   <= 1'b0; 
			des_fifo_rd_strb_z2	   <= 1'b0;
			des_fifo_rd_strb_z3	   <= 1'b0;
			des_fifo_rd_strb_z4	   <= 1'b0;
         des_fifo_rd_strb_z5	   <= 1'b0;
         des_fifo_rd_strb_z6	   <= 1'b0;
         dat_tf_done_z1			   <= 1'b0;
		end
		else begin										  
			sd_clk_stab_reg_z1		<= sd_clk_stab_reg;
			new_resp_pkt_strb_z1		<= new_resp_pkt_strb;
			new_resp_pkt_strb_z2		<= new_resp_pkt_strb_z1;
			new_resp_2_pkt_strb_z1	<= new_resp_2_pkt_strb;	
			end_bit_det_strb_z1		<= end_bit_det_strb;
			present_state_z1			<= present_state;	
			normal_int_status_z1	   <= normal_int_status;	
			wr_reg_strb_z1				<= wr_reg_strb;	  
			wr_reg_strb_z2				<= wr_reg_strb_z1;			  
			wr_busy_z1					<= wr_busy;
			des_fifo_rd_strb_z1	   <= des_fifo_rd_strb; 
			des_fifo_rd_strb_z2	   <= des_fifo_rd_strb_z1;
			des_fifo_rd_strb_z3	   <= des_fifo_rd_strb_z2;
			des_fifo_rd_strb_z4	   <= des_fifo_rd_strb_z3;
			des_fifo_rd_strb_z5	   <= des_fifo_rd_strb_z4;
			des_fifo_rd_strb_z6	   <= des_fifo_rd_strb_z5;
         dat_tf_done_z1			   <= dat_tf_done;
		end
	end																							
	////////////////////////////////////////////////////////////////////////////
	
	// Select which map register to send away to the bus host driver.	
	// This process is not polled.  It only happens when one of the
	// sensitivity items changes.
	always@(rd_reg_index, block_size, block_count, argument_1, 
				transfer_mode, command, response, present_state, clock_cntrl,
				normal_int_status, error_int_status, capabilities, 
				adma_system_addr, dat0_crc)
	begin
		case (rd_reg_index[11:0])
			// Need to fill in the packet according to the register size of
			// each map register because reg_selected has 128 bits.  Some
			// responses has 128 bits.							
			12'h004	:	reg_selected <= {{112{1'b0}}, block_size};
			12'h006	:	reg_selected <= {{112{1'b0}}, block_count};
			12'h008	:	reg_selected <= {{96{1'b0}}, argument_1};	
			12'h00C	:	reg_selected <= {{112{1'b0}}, transfer_mode};
			12'h00E	:	reg_selected <= {{112{1'b0}}, command};
			12'h010	:	reg_selected <= response;
			12'h024	:	reg_selected <= {{96{1'b0}}, present_state};
			12'h02C	:	reg_selected <= {{116{1'b0}}, clock_cntrl};
			12'h030	:	reg_selected <= {{116{1'b0}}, normal_int_status};
			12'h032	:	reg_selected <= {{116{1'b0}}, error_int_status};
			12'h040	:	reg_selected <= {{64{1'b0}}, capabilities};
			12'h058	:	reg_selected <= adma_system_addr;
			// Followings are not part of host controller register map.
			12'h0FF	:	reg_selected <= {{112{1'b0}}, dat0_crc};
			default 	: 	reg_selected <= {128{1'b0}};
		endcase
	end	 
	
	// Gate the selected register
	always@(posedge clk)
	begin
		if (reset)
			rd_reg_output <= {128{1'b0}};
		//else if (rd_strb)
		else
			rd_reg_output <= reg_selected;      
	end										 
	
	//-------------------------------------------------------------------------
	// We need a generic 64 sdclcks counter to find out if a response was 
	// coming back.  This is for the Command Timeout Error generation. 
	//-------------------------------------------------------------------------
	defparam gen64sdclksCntr_u6.dw 	= 8;
	defparam gen64sdclksCntr_u6.max	= 8'h40;	
	//-------------------------------------------------------------------------
	CounterSeq gen64sdclksCntr_u6(
		.clk(sdc_clk), // sdc_clk 
		.reset(reset),	
		.enable(1'b1), 					 
		// start the timing after we sent out the stop bit
		// wonder if this would work, since we are using an
		// edge detection.
		.start_strb(end_bit_det_strb && !end_bit_det_strb_z1),   	 	
		.cntr(), 
		.strb(fin_64sdclks_strb) 
	);   
    
	// Parse for end_descr.
   always @(posedge clk) begin
      if (reset)
         end_descr <= 1'b0;
      else if (des_fifo_rd_strb_z5) // wait for 5 clocks
         end_descr <= des_rd_data[1];
   end	
	
	////////////////////////////////////////////////////////////////////////////
	// Start of the register map updating.
	// Some of these register bits are changed by the SD Host Controller.
	// Some are changed by the Host Driver.
	////////////////////////////////////////////////////////////////////////////
	
	// Update present_state[0].
	// This bit is set immediately after the Command register (00Eh) is written. 
	// This bit is cleared when the command response is received.
	// 1 Cannot issue command
	// 0 Can issue command using only CMD line
	// Command Inhibit (CMD)
	// If this bit is 0, it indicates the CMD line is not in use and the Host 
	// Controller can issue a SD Command using the CMD line.
	// This bit is set immediately after the Command register (00Fh) is written. 
	// This bit is cleared when the command response is received. Auto CMD12 
	// and Auto CMD23 consist of two responses. In this case, this bit is not 
	// cleared by the response of CMD12 or CMD23 but cleared by the response of 
	// a read/write command. Status issuing Auto CMD12 is not read from this bit. 
	// So if a command is issued
	// during Auto CMD12 operation, Host Controller shall manage to issue two
	// commands: CMD12 and a command set by Command register.
	// Even if the Command Inhibit (DAT) is set to 1, commands using only the  
	// CMD line can be issued if this bit is 0. Changing from 1 to 0 generates a 
	// Command Complete Interrupt in the Normal Interrupt Status register.
	// If the Host Controller cannot issue the command because of a command 
	// conflict error (Refer to Command CRC Error in Section 2.2.18) or because 
	// of Command Not Issued By Auto CMD12 Error (Refer to Section 2.2.23), 
	// this bit shall remain 1 and the Command Complete is not set.
	// Implementation Note:
	// Some fields defined in the Present State Register change values 
	// asynchronous to the system clock.  The System reads these statuses 
	// through the System Bus Interface and it may require data stable
	// period during bus cycle. The Host Controller should sample and hold 
	// values during reads from this register according to the timing required 
	// by the System Bus Interface specification.
	
	// Update present_state[1], Command Inhibit (DAT).
	// Command Inhibit (DAT)
	// This status bit is generated if either the DAT Line Active or the 
	// Read Transfer Active is set to 1. If this bit is 0, it indicates
	// the Host Controller can issue the next
	// SD Command. Commands with busy signal belong to Command Inhibit (DAT)
	// (ex. R1b, R5b type). Changing from 1 to 0 generates a Transfer Complete
	// interrupt in the Normal Interrupt Status register.
	// Note: The SD Host Driver can save registers in the range of 000-00Dh for 
	// a suspend transaction after this bit has changed from 1 to 0.
	always@(posedge clk)
	begin
		if (reset) 													 
			present_state		<= {32{1'b0}};													
		// The Command Inhibit (CMD) bit.
		// triggers by the send command		
		// This bit is set immediately after the Command register (00Eh)
		// is written.  This bit is cleared when the command response 
		// is received.  Changing from 1 to 0 generates a Command
		// Complete Interrupt in the Normal Interrupt Status register.
		// If it's command 0, we do not raise bit 0.  There is no response
		// for command 0.
		else if (wr_reg_index == 12'h00E && wr_reg_strb_z1 && (command[13:8] > 6'h00))
			present_state		<= present_state | 32'h0000_0001;
		// clears command inhibit (CMD) bit.
		// This bit is cleared when the command response is received.
		// For both kinds of responses?
		// new_resp_pkt_strb cannot be used for cmd12 and 23.
		// need to take care of this.
		// also need to take of this when cmd 12 and 23 are issued.
		// Careful if wr_reg_index is a strobe.
		// new_resp_pkt_strb indicates the end bit of the command response.
		// Use falling edge because new_resp_pkt_strb is from the sdc_clock. 							  
		else if ((!new_resp_pkt_strb && new_resp_pkt_strb_z1) ||
					(!new_resp_2_pkt_strb && new_resp_2_pkt_strb_z1 || software_reset[1])) 
			present_state 		<= present_state & 32'hFFFF_FFFE;
		// Command Inhibit (DAT) bit.
		// need to take care of these two conditions
		//else if (present_state[2] || present_state[9]) 
//			present_state	 	<= present_state | 32'h0000_0002;
//		// to clear this bit.
//		else if (!present_state[2] || !present_state[9]) begin 
//			present_state 		<= present_state & 32'hFFFF_FFFD;
//		end
		// end bit of write command detected
		// This bit could also be set when we are reading data.
		// This bit is set after the end bit of the write command. 
		// But the command has to be the send data command (24d, 18h) or (25d, 19h).
		// Update present_state[1], Command Inhibit (DAT).
		else if ((end_bit_det_strb && (!end_bit_det_strb_z1)) && ((command[13:8] == 6'h18) || (command[13:8] == 6'h19)))	// rising edge 
			present_state	 	<= present_state | 32'h0000_0004;
		// Clear it when DAT0 is not busy any more and we have reached the last 
		// block of data, ie, the last decriptor table.					  
		// We should also clear this bit if the SD card does not drive the bus signal
		// for 8 SD clocks.  We could also clear this bit after some time after we
		// sent the data just so we don't get stuck in this bit.
		else if (!wr_busy && wr_busy_z1 && end_descr)            // falling edge                        
			present_state 		<= present_state & 32'hFFFF_FFFB;   
//		// If card is inserted, bit 16                           
//		else if (card_inserted_strb)                             
//			present_state		<= present_state | 32'h0001_0000;   
//		// If card is removed, bit 16                            
//		else if (card_removed_strb)                              
//			present_state		<= present_state & 32'hFFFE_FFFF;   
		else if (software_reset[2])                              // software reset[2]                      
			present_state 		<= present_state & 32'hFFF0_FFF9;
		else 
			present_state 		<= present_state;
	end  	

	// 2.2.17 Normal Interrupt Status Register (Offset 030h) (pg 63)
	// Changing from 1 to 0 generates a Command Complete Interrupt
	// in the Normal Interrupt Status register.
	// If the Host Controller cannot issue the command because of a command conflict
	// error (Refer to Command CRC Error in Section 2.2.18) or because of Command
	// Not Issued By Auto CMD12 Error (Refer to Section 2.2.23), this bit shall remain 1
	// and the Command Complete is not set.
	// (1) In the case of a Read Transaction
	// This bit is set at the falling edge of Read Transfer Active Status
	// (Present State Register).
	// This interrupt is generated in two cases. The first is when a data
	// transfer is completed as specified by data length (After the last data
	// has been read to the Host System). The second is when data has
	// stopped at the block gap and completed the data transfer by setting
	// the Stop At Block Gap Request in the Block Gap Control register
	// (After valid data has been read to the Host System). Refer to Section
	// 3.12.3 for more details on the sequence of events.
	// (2) In the case of a Write Transaction
	// This bit is set at the falling edge of the DAT Line Active Status. This
	// interrupt is generated in two cases. The first is when the last data is
	// written to the SD card as specified by data length and the busy signal
	// released. The second is when data transfers are stopped at the block
	// gap by setting Stop At Block Gap Request in the Block Gap Control
	// register and data transfers completed. (After valid data is written to
	// the SD card and the busy signal released). Refer to Section 3.12.4 for
	// more details on the sequence of events.
	// (3) In the case of a command with busy
	// This bit is set when busy is de-asserted. Refer to DAT Line Active
	// and Command Inhibit (DAT) in the Present State register.
	always@(posedge clk)
	begin
		if (reset) 
//			normal_int_status[0] <= 1'b0; // Command Complete Interrupt
//			normal_int_status[1] <= 1'b0; // transfer complete int
//			normal_int_status[6] <= 1'b0; // Card Insertion Interrupt
//			normal_int_status[7] <= 1'b0; // Card Removal int
			normal_int_status		<= {16{1'b0}};
		// The following else ifs are for enabling the bits.
		else if (normal_int_status_enb[0] && 							// if enabled
					(!present_state[0] && present_state_z1[0]) && 	// falling edge 
					!error_int_status[1]) 	 								// and no CRC error 
			// Command Complete Int set, could be cleared by host bus driver 
			// (RWC1 command).  Command Inhibit (CMD) from Present State Reg. 
			// goes from 1 to 0 indicating a command was successful.
			normal_int_status	 	<= normal_int_status | 16'h0001;	
		else if (normal_int_status_enb[1] && // if enabled
						// DAT Line Active changed.
					((!present_state[2] && present_state_z1[2]) /*|| 	// falling edge
						// Command Inhibit (DAT) changed.
					(!present_state[1] && present_state_z1[1]) ||	// falling edge
						// Read Transfer Active changed.
					(!present_state[9] && present_state_z1[9])*/)/*&& // falling edge 
					!error_int_status[1]*/) 								// and no error
			// Transfer Complete Int set, could be cleared by host bus driver 
			// (RWC1 command).		
			normal_int_status	 	<= normal_int_status | 16'h0002; 
		else if (normal_int_status_enb[6] && 							// if enabled
					(present_state[16] && !present_state_z1[16]) && // rising edge 
					!error_int_status[6])  							// and no error 
			// Card Insertion Int set, could be cleared by host bus driver 
			// (RW1C command)		
			normal_int_status		<= normal_int_status | 16'h0040;
		else if (normal_int_status_enb[7] && 							// if enabled
					(!present_state[16] && present_state_z1[16]) && // falling edge 
					!error_int_status[7])  							      // and no error 
			// Card Removal Int set, could be cleared by host bus driver 
			// (RW1C command)		
			normal_int_status 	<= normal_int_status | 16'h0080;
		// The following else if is for clearing the bit.
		// Write to 2.2.17 Normal Interrupt Status Register (Offset 030h) (pg 63).
		// This is when the bus host driver tries to clear or leave unchanged 
		// the bits.  At this point, we'll assume that the status enable bit
		// has already been enabled for the appropriate bit.  reg_attr == 3'h3 is
		// a RW1C command, see 2.1.2 Configuration Register Types, pg 20.
		else if (wr_reg_index == 12'h030 && wr_reg_strb && reg_attr == 3'h3) 
		begin      
			// We may need to do for all bits of wr_reg_input depending on
			// which bit we are working with.
			if (wr_reg_input[0])  // clear bit if 1
				normal_int_status <= normal_int_status & 16'hFFFE;	// Command Complete Int
			else if (wr_reg_input[1])  // clear bit if 1
				normal_int_status <= normal_int_status & 16'hFFFD; // Transfer Complete
			else if (wr_reg_input[6])  // clear bit if 1
				normal_int_status <= normal_int_status & 16'hFFBF; // Card Inserted Int
			else if (wr_reg_input[7])  // clear bit if 1
				normal_int_status <= normal_int_status & 16'hFF7F; // Card Removed Int
			else  // leave everything as is
				normal_int_status <= normal_int_status;
		end
		else if (software_reset[1])                              // clear bit if 1 for software reset
			normal_int_status    <= normal_int_status & 16'hFFFE;	// Command Complete Int	
		else if (software_reset[2])                              // clear bit if 1 for software reset
			normal_int_status    <= normal_int_status & 16'hFFC1;	// 	
		else  // default case
			normal_int_status 	<= normal_int_status;
//			normal_int_status[1] <= normal_int_status[1];
//			normal_int_status[6] <= normal_int_status[6];
//			normal_int_status[7] <= normal_int_status[7];
	end
	
	// 2.2.19 Normal Interrupt Status Enable Register (Offset 034h)
	// Setting to 1 only enables Status register updating.
	// Enable this bit and the Signal Enable bit triggers an
	// interrupt.
	always@(posedge clk)
	begin
		if (reset) 
			normal_int_status_enb 	<= 16'h01CB;
		else if (wr_reg_index == 12'h034 && wr_reg_strb)       
			// To write a bit or it, to erase a bit, and it.
			normal_int_status_enb 	<= wr_reg_input[15:0] | normal_int_status_enb;
		else  // default case
			normal_int_status_enb 	<= normal_int_status_enb;
	end
	
	// 2.2.21 Normal Interrupt Signal Enable Register (Offset 038h)
	// This register is used to select which interrupt status is indicated to 
	// the Host System as the interrupt. These status bits all share the same 1 
	// bit interrupt line. Setting any of these bits to 1 enables interrupt
	// generation.
	// To set an interrupt, you need to set this bit and the Status Enbable bit.
	always@(posedge clk)
	begin
		if (reset) 
			normal_int_signal_enb 	<= 16'h01CB;
		else if (wr_reg_index == 12'h038 && wr_reg_strb)       
			normal_int_signal_enb 	<= wr_reg_input[15:0];
		else  // default case
			normal_int_signal_enb 	<= normal_int_signal_enb;
	end 
	
	// Need to write code for Read Transfer Active and DAT Line Active later 
	// when we get to reading and writting.  This goes for other registers
	// as well.
	
	// 2.2.18 Error Interrupt Status Register (Offset 032h) (pg 68)
	// Command CRC Error is generated in two cases.
	// If a response is returned and the Command Timeout Error is set to 0
	// (indicating no timeout), this bit is set to 1 when detecting a CRC error 
	// in the command response.  Need to compare the command crc and its 
	// response crc.  The Host Controller detects a CMD line conflict by 
	// monitoring the CMD line when a command is issued. If the Host Controller
	// drives the CMD line to 1 level, but detects 0 level on the CMD line 
	// at the next SD clock edge, then the Host Controller shall abort the 
	// command (Stop driving CMD line) and set this bit to 1. The Command 
	// Timeout Error shall also be set to 1 to distinguish CMD
	// line conflict (Refer to Table 2-25).
	always@(posedge clk)
	begin
		if (reset) 
			error_int_status	 	<= {16{1'b0}};			
			//error_int_status[9] <= 1'b0;			// ADMA error int		
		// We need to take care of the Command Timeout Error.
		// If we don't get a response after 64 sdc_clks, we neeed to
		// set this error.
		else if (!resp_recvd && fin_64sdclks_strb && error_int_status_enb[0])
			error_int_status 		<= error_int_status | 16'h0001;// Command Timeout Error
		// Takes care of the command crc error if enabled in the Command
		// and Error Interrupt Status Enable registers.  Also, we only check this
		// when we don't have a timeout error.
		else if (cmd_crc_err && error_int_status_enb[1]
					&& !error_int_status[0]) 							 // no timeout error
			error_int_status 		<= error_int_status | 16'h0002;// Command CRC Error
		// Takes care of the command index error if enabled in the Command
		// and Error Interrupt Status Enable registers.
		else if (cmd_indx_err && error_int_status_enb[3])			
			error_int_status 		<= error_int_status | 16'h0008;	// Command CRC Error
//		else if (new_resp_pkt_strb && error_int_status_enb[1] 
//					&& !error_int_status[0] && 	// no timeout error
//					(r1_crc7_good_out | r2_crc7_good_out))// command crc7 good
//			error_int_status[1] <= 1'b0; 			// Clear Command CRC Error
	// ADMA Error
	// This bit is set when the Host Controller detects errors during ADMA based 
	// data transfer. The state of the ADMA at an error occurrence is saved in 
	// the ADMA Error Status Register,
	// In addition, the Host Controller generates this Interrupt when it detects 
	// invalid descriptor data (Valid=0) at the ST_FDS state. ADMA Error State 
	// in the ADMA Error Status indicates that an error occurs in ST_FDS state.
	// The Host Driver may find that Valid bit is not set at the error 
	// descriptor.
	// We'll write this code as we get to the adma state machine and sending
	// or reading the data.
		else if ((new_resp_pkt_strb && !new_resp_pkt_strb_z1) && error_int_status_enb[9] 
					&& !error_int_status[0] && // no timeout error
					cmd_crc_err)					// command crc7 not good
			error_int_status 		<= error_int_status | 16'h0200;// Command ADMA Error
//		else if (new_resp_pkt_strb && error_int_status_enb[9] 
//					&& !error_int_status[0] && 	// no timeout error
//					(r1_crc7_good_out | r2_crc7_good_out))// command crc7 good
//			error_int_status[9] <= 1'b0; 			// Clear sCommand CRC Error
		// Need to clear the bit by the bus host driver.
		else if (wr_reg_index == 12'h032 && wr_reg_strb && reg_attr == 3'h3) 
		begin      
			// We may need to do for all bits of wr_reg_input depending on
			// which bit we are working with.
			if (wr_reg_input[0])  		// clear bit if 1
				error_int_status 	<= error_int_status & 16'hFFFE;// Command Timeout Err
			else if (wr_reg_input[1])  // clear bit if 1
				error_int_status 	<= {error_int_status[15:2], 
											~error_int_status[1], 
											error_int_status[0]}; // Command CRC Error
			else if (wr_reg_input[6])  // clear bit if 1
				error_int_status 	<= {error_int_status[15:7], 
											~error_int_status[6], 
											error_int_status[5:0]}; // Data End Bit Error
			else if (wr_reg_input[7])  // clear bit if 1
				error_int_status 	<= {error_int_status[15:8], 
											~error_int_status[7], 
											error_int_status[6:0]}; // Current Limit Error
			else if (wr_reg_input[9])  // clear bit if 1
				error_int_status 	<= {error_int_status[15:10], 
											~error_int_status[9], 
											error_int_status[8:0]}; // ADMA Error
			else  // leave everything as is
				error_int_status 	<= error_int_status;
		end
		else
			error_int_status 		<= error_int_status;	 
	end	  
	
	// 2.2.20 Error Interrupt Status Enable Register (Offset 036h)
	// Setting to 1 only updates the Status register.
	// To trigger an interrupt, you need to set this bit and the
	// Signal Enable bit.
	always@(posedge clk)
	begin
		if (reset)
			error_int_status_enb 	<= {16{1'b0}};
		else if (wr_reg_index == 12'h036 && wr_reg_strb)       
			error_int_status_enb 	<= wr_reg_input[15:0];
		else  // default case
			error_int_status_enb 	<= error_int_status_enb;
	end
	
	// 2.2.22 Error Interrupt Signal Enable Register (Offset 03Ah)
	// This register is used to select which interrupt status is notified to the 
	// Host System as the interrupt. These status bits all share the same 1 bit 
	// interrupt line. Setting any of these bits to 1 enables interrupt generation.
	// To set an interrupt, you need to set this bit and the Status Enbable bit.
	
	always@(posedge clk)
	begin
		if (reset) 
			error_int_signal_enb 	<= {16{1'b0}};
		else if (wr_reg_index == 12'h036 && wr_reg_strb)       
			error_int_signal_enb 	<= wr_reg_input[15:0];
		else  // default case
			error_int_signal_enb 	<= error_int_signal_enb;
	end
	
	// 2.2.18 Error Interrupt Status Register (Offset 032h) (pg 68)
	// ADMA Error
	// This bit is set when the Host Controller detects errors during ADMA based 
	// data transfer. The state of the ADMA at an error occurrence is saved in 
	// the ADMA Error Status Register,
	// In addition, the Host Controller generates this Interrupt when it detects 
	// invalid descriptor data (Valid=0) at the ST_FDS state. ADMA Error State 
	// in the ADMA Error Status indicates that an error occurs in ST_FDS state.
	// The Host Driver may find that Valid bit is not set at the error 
	// descriptor.
	// We'll write this code as we get to the adma state machine and sending
	// or reading the data.
//	always@(posedge clk)
//	begin
//		if (reset)
//			error_int_status[9] <= 1'b0;			// ADMA error int
//		else if (new_resp_pkt_strb && error_int_signal_enb[9] 
//					&& !error_int_status[0] && 	// no timeout error
//					(!r1_crc7_good_out | !r2_crc7_good_out))// command crc7 not good
//			error_int_status[9] <= 1'b1;			// Command CRC Error
//		else if (new_resp_pkt_strb && error_int_signal_enb[9] 
//					&& !error_int_status[0] && 	// no timeout error
//					(r1_crc7_good_out | r2_crc7_good_out))// command crc7 good
//			error_int_status[9] <= 1'b0; 			// Clear sCommand CRC Error
//		else
//			error_int_status[9] <= error_int_status[9];
//	end

	// Update the 2.2.7 Response Register (Offset 010h).
	always@(posedge clk)
	begin
		if (reset) 
			response 				<= {128{1'b0}};
		// Table 2-12 : Response Bit Definition for Each Response Type.
					// rising edge
		//else if (new_resp_pkt_strb && !new_resp_pkt_strb_z1) begin		
					// falling edge
		else if (!new_resp_pkt_strb && new_resp_pkt_strb_z1) begin
			//if (kind_of_resp == 3'h0 || kind_of_resp == 3'h4 ||
//				 kind_of_resp == 3'h5 || kind_of_resp == 3'h6 ||
//				 kind_of_resp == 3'h7) 
//				response[31:0]		<= response_packet[39:8];
			//else if (kind_of_resp == 3'h1 || kind_of_resp == 3'h2)
			//if (kind_of_resp == 3'h1 || kind_of_resp == 3'h2)
			if (command[13:8] == 3'h1 || command[13:8] == 3'h2) 
				response[127:96]	<= response_packet[39:8]; 
			// This is for automated command index setting.  CMD24 is for sending
	   	// one block of data.  kind_of_resp right now can only be generated by
			// manual commands in the host bus driver.  We need to generate kind_of_resp
			// for automated command also.  Or come up with a way to packet the response_packet
		   // coming back correctly into the response[127:0] register.
			//	else if ((!new_resp_pkt_strb && new_resp_pkt_strb_z1) && (command[13:8] == 6'd24))
//					response[31:0]		<= response_packet[39:8];
			else
				response[31:0]		<= response_packet[39:8];
		end		// rising edge									
		// This for automated command index setting.  CMD24 is for sending
	   // one block of data.
		//else if ((!new_resp_pkt_strb && new_resp_pkt_strb_z1) && (command[13:8] == 6'd24))
//				response[31:0]		<= response_packet[39:8];
		//else if (new_resp_2_pkt_strb && !new_resp_2_pkt_strb_z1)  // for CID or CSD
		else if (!new_resp_2_pkt_strb && new_resp_2_pkt_strb_z1)  // for CID or CSD
			response[119:0]		<= r2_packet[127:8];
		else
			response 				<= response;
	end
	
	// 2.2.30 ADMA System Address Register (Offset 058h)
	// This register contains the physical Descriptor address used for ADMA data 
	// transfer.
	// ADMA System Address
	// This register holds byte address of executing command of the Descriptor 
	// table. 32-bit Address Descriptor uses lower 32-bit of this register. At 
	// the start of ADMA, the Host Driver shall set start address of the 
	// Descriptor table. The ADMA increments this register address, which points 
	// to next line, when every fetching a Descriptor line. When the ADMA Error 
	// Interrupt is generated, this register shall hold valid Descriptor address 
	// depending on the ADMA state. The Host Driver shall program Descriptor
	// Table on 32-bit boundary and set 32-bit boundary address to this 
	// register.  ADMA2 ignores lower 2-bit of this register and assumes 
	// it to be 00b.
	always@(posedge clk)
	begin
		if (reset)
			adma_system_addr  <= {32{1'b0}};
		else if (adma_sar_inc_strb)
			adma_system_addr  <= adma_system_addr + 1'b1; 
		else if (wr_reg_index == 12'h058 && wr_reg_strb)       
			adma_system_addr  <= wr_reg_input;
		else
			adma_system_addr  <= adma_system_addr;
	end // we have to put this together with the host bus driver code.	
	
	// 2.2.14 Clock Control Register (Offset 02Ch)
	always@(posedge clk)
	begin
		if (reset) 
			clock_cntrl 	<= {16{1'b0}};
		// For testing, take out after done.
//		if (wr_reg_index == 12'h00E && wr_reg_strb) begin 
//			clock_cntrl		<= clock_cntrl | 16'h0003;
//		end
		// We can set the bits here.
		else if (wr_reg_index == 12'h02C && wr_reg_strb)   
			clock_cntrl 	<= clock_cntrl | wr_reg_input[15:0]; 	// or to set	
		// When the internal clock enable bit is switched off, 
		// switch off the internal clock stable bit.							 
		// This is when the bus host driver tries to clear or leave unchanged 
		// the bits.  You can only do one bit at a time.  Cannot do more than
		// one bit at a time.
		else if (wr_reg_index == 12'h02C && wr_reg_strb_z2 && reg_attr == 3'h3) 
		begin      
			// We may need to do for all bits of wr_reg_input depending on
			// which bit we are working with.
			if (wr_reg_input[0])  		// clear bit if 1, internal clk disable
				//clock_cntrl <= {clock_cntrl[15:1],{1'b0}};
				//clock_cntrl 	<= {16{1'b0}};							
				clock_cntrl <= clock_cntrl & 16'hFFFE;
			else if (wr_reg_input[2])  // clear bit if 1, sd clk disable							
				//clock_cntrl <= clock_cntrl & 16'hFFFB;		
				clock_cntrl <= {clock_cntrl[15:3],{1'b0},clock_cntrl[1:0]};
			// The next eight bits, we will clear the sdclk freq. sel. bits.
			else if (wr_reg_input[8])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15:9],{1'b0},clock_cntrl[7:0]};
			else if (wr_reg_input[9])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15:10],{1'b0},clock_cntrl[8:0]};
			else if (wr_reg_input[10])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15:11],{1'b0},clock_cntrl[9:0]};
			else if (wr_reg_input[11])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15:12],{1'b0},clock_cntrl[10:0]};
			else if (wr_reg_input[12])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15:13],{1'b0},clock_cntrl[11:0]};
			else if (wr_reg_input[13])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15:14],{1'b0},clock_cntrl[12:0]};
			else if (wr_reg_input[14])  // clear bit if 1
				clock_cntrl <= {clock_cntrl[15],{1'b0},clock_cntrl[13:0]};	  
			else if (wr_reg_input[15])  // clear bit if 1
				clock_cntrl <= {{1'b0},clock_cntrl[14:0]};
			else  // leave everything as is
				clock_cntrl <= clock_cntrl;
		end  
		else if (sd_clk_stable) // May use rising edge? 	      
			clock_cntrl 	<= clock_cntrl | {{14{1'b0}}, {1'b1}, {1'b0}};
		else if (!clock_cntrl[0]) 	      
			clock_cntrl 	<= clock_cntrl & {{14{1'b1}}, {1'b0}, {1'b0}};
		else  // default case
			clock_cntrl 	<= clock_cntrl;
	end		
	
	// 2.2.16 Software Reset Register (Offset 02Fh)
	// A reset pulse is generated when writing 1 to each bit of this register. 
   // After completing the reset, the Host Controller shall clear each bit. 
   // Because it takes some time to complete software reset, the SD Host Driver
   // shall confirm that these bits are 0.
	always@(posedge clk)
	begin
		if (reset) 
			software_reset 	<= 8'h00;
		else if (wr_reg_index == 12'h02F && wr_reg_strb)       
			software_reset 	<= wr_reg_input[7:0];
		else  // default case
			software_reset 	<= software_reset;
	end 
	
	// Write to 2.2.4 Argument 1 Register (Offset 008h).
	// Update the argument field of the send command.
	always@(posedge clk)
	begin
		if (reset)
			argument_1 	<= {32{1'b0}};
		else if (wr_reg_index == 12'h008 && wr_reg_strb)      
			argument_1 	<= wr_reg_input;
		else  // default case
			argument_1 	<= argument_1;
	end

	// Write to 2.2.5 Transfer Mode Register (Offset 00Ch).
	always@(posedge clk)
	begin
		if (reset)
			transfer_mode 	<= {16{1'b0}};
		else if (wr_reg_index == 12'h00C && wr_reg_strb)       
			transfer_mode 	<= wr_reg_input[15:0];
		else  // default case
			transfer_mode 	<= transfer_mode;
	end

	// Write to 2.2.6 Command Register (Offset 00Eh).
	// Update the Command Register as we send a command to the SD Card.
	always@(posedge clk)
	begin
		if (reset)
			command 	<= {16{1'b0}};
		else if (wr_reg_index == 12'h00E && wr_reg_strb)      
			command 	<= wr_reg_input[15:0];
		// When we have finished trasfering all the data blocks 
		// (Transfer Complete), we need to send the stop command CMD12. 
		// But only if Auto CMD12 is enabled in the transfer_mode.
//		else if (normal_int_status[1] == 1'b1 && transfer_mode[3:2] == 2'b01)   
//			command 	<= {{2{1'b0}}, 6'h0C, command[7:0]};
		else  // default case
			command 	<= command;
	end
	
	// 2.2.2 Block Size Register (Offset 004h)
	// Transfer Block Size
	// This register specifies the block size of data transfers for CMD17, CMD18,
	// CMD24, CMD25, and CMD53. Values ranging from 1 up to the maximum buffer
	// size can be set. In case of memory, it shall be set up to 512 bytes (Refer 
	// to Implementation Note in Section 1.7.2). It can be accessed only if no 
	// transaction is executing (i.e., after a transaction has stopped). 
	// Read operations during transfers may return an invalid value,
	// and write operations shall be ignored.
	always@(posedge clk)
	begin
		if (reset) 
			block_size 	<= {16{1'b0}};
		// For testing, take out after done.
//		if (wr_reg_index == 12'h00E && wr_reg_strb) begin 
//			block_size		<= block_size | 16'h0002;
//		end
		else if (wr_reg_index == 12'h004 && wr_reg_strb)       
			block_size 	<= wr_reg_input[15:0];
		else  // default case
			block_size 	<= block_size;
	end
	
	// 2.2.3 Block Count Register (Offset 006h)
	// This register is used to configure the number of data blocks.
	// Blocks Count For Current Transfer
	// This register is enabled when Block Count Enable in the Transfer Mode 
	// register is set to 1 and is valid only for multiple block transfers. 
	// The Host Driver shall set this register to a value between 1 and the 
	// maximum block count. The Host Controller
	// decrements the block count after each block transfer and stops when the 
	// count reaches zero. Setting the block count to 0 results in no data 
	// blocks is transferred.  This register should be accessed only when no 
	// transaction is executing (i.e., after transactions are stopped). 
	// During data transfer, read operations on this register may
	// return an invalid value and write operations are ignored.
	// When a suspend command is completed, the number of blocks yet to be 
	// transferred can be determined by reading this register. Before issuing a 
	// resume command, the Host Driver shall restore the previously saved block 
	// count.
	always@(posedge clk)
	begin
		if (reset)
			block_count 	<= {16{1'b0}};
		// For testing, take out after done.
//		if (wr_reg_index == 12'h00E && wr_reg_strb) begin 
//			block_count		<= block_count | 16'h0004;
//		end
		else if (wr_reg_index == 12'h006 && wr_reg_strb)       
			block_count 	<= wr_reg_input[15:0];
		else  // default case
			block_count 	<= block_count;
	end
	////////// End of Register Map /////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	
	// We will start to send the command when we get the wr_reg_index == 12'h00E
	// register.  
	always@(posedge clk)
	begin
		if (reset)
			new_cmd_set_strb 	<= 1'b0;
		else if (wr_reg_index == 12'h00E && wr_reg_strb)       
			new_cmd_set_strb 	<= 1'b1;
		else  // default case
			new_cmd_set_strb 	<= 1'b0;
	end				 	 
	
	// We will start to send the command when we get the wr_reg_index == 12'h00E
	// register.  Also, when we have finished trasfering all the data blocks 
	// (Transfer Complete), we need to send the stop command CMD12.
	// But only if Auto CMD12 is enabled in the transfer_mode.
//	always@(posedge clk)
//	begin
//		if (reset)
//			snd_auto_cmd12_strb 	<= 1'b0;
//      else if ((~normal_int_status_z1[1] && normal_int_status[1]) && transfer_mode[3:2] == 2'b01)
//			snd_auto_cmd12_strb 	<= 1'b1;
//		else  // default case cause a strobe
//			snd_auto_cmd12_strb 	<= 1'b0;
//	end	
																	
	// We'll update the command crc error here.
	always@(posedge clk)
	begin
		if (reset)
			cmd_crc_err	<= 1'b0;
		// If the command crc check enable bit is set in the command
		// and the crcs of the command and response packet are the
		// same, there is no command crc error.  Otherwise, there is
		// an error.  But do this only after we have received a response.
		else if (command[3] && (command[7:1] == response_packet[7:1])
					&& resp_recvd) 
			cmd_crc_err	<= 1'b0;
		else if (command[3] && (command[7:1] != response_packet[7:1])
					&& resp_recvd) 
			cmd_crc_err	<= 1'b1;
		else 
			cmd_crc_err	<= 1'b0;
	end			 	 
																	
	// We'll update the command index error here.
	always@(posedge clk)
	begin
		if (reset)
			cmd_indx_err	<= 1'b0;
		// If the command index check enable bit is set in the command
		// and the command indexes of the command and response packet are the
		// same, there is no command index error.  Otherwise, there is
		// an error.  But do this only after we have received a response.
		else if (command[4] && (command[13:8] == response_packet[45:40])
					&& resp_recvd) 
			cmd_indx_err	<= 1'b0;
		else if (command[4] && (command[13:8] != response_packet[45:40])
					&& resp_recvd) 
			cmd_indx_err	<= 1'b1;
		else 
			cmd_indx_err	<= 1'b0;
	end
	
	// We need to start the ADMA2 state machine when we get a response back
	// from one of the write or read commands.  It could be multiple or single 
	// write or read.
	always@(posedge clk)
	begin
		if (reset)
			strt_dat_tf 	<= 1'b0;	// cmd17 or cmd18 
		else if ((command[13:8] == 6'h11 || command[13:8] == 6'h12 || 
											// cmd24 or cmd25
					 command[13:8] == 6'h18 || command[13:8] == 6'h19) &&  
					 (!new_resp_pkt_strb && new_resp_pkt_strb_z1)) // falling edge, from sd clk
			strt_dat_tf 	<= 1'b1;	// assume ready_for_data bit is set.
//			strt_dat_tf 	<= response[8]; // Card Status ready_for_data bit.	 
		//else if ((command[13:8] == 6'h11 || command[13:8] == 6'h12 || 
//											// cmd24 or cmd25
//					 command[13:8] == 6'h18 || command[13:8] == 6'h19) &&  
//					 (response[8] == 1'b1))  // Card Status ready_for_data bit
//			strt_dat_tf 	<= 1'b1;
		else  // default case
			strt_dat_tf 	<= 1'b0;
	end
	
	// We need a latch to indicate that we have a response.
	always@(posedge clk)
	begin
		if (reset)
			resp_recvd 	<= 1'b0;
			// Becareful, new_resp_pkt_strb is actually using
			// the sdc_clk.  We should actually just use the
			// rising edge.  But in this case it is okay
			// to use it this way since resp_recvd is a latch.
		else if (new_resp_pkt_strb || new_resp_2_pkt_strb)
			resp_recvd 	<= 1'b1;	// set the latch		
		else if (new_cmd_set_strb)
			resp_recvd 	<= 1'b0;	// release the latch		
		else  // maintain latch
			resp_recvd 	<= resp_recvd;
	end	
	
	//-------------------------------------------------------------------------
	// We need to stretch out the snd_cmd_strb wide enough so we
	// can start the sdc_cmd_mod.  This is according to the clock control
	// register bits 15:8 (SDCLK Frequency Select).  We are using the 8-bit
	// divided clock mode.  May need different counters for different
	// SDCLK Frequency Select.  This is because different clocks need
	// different strobe length.
	//-------------------------------------------------------------------------
	defparam strtchStrb40h_u7.dw 	= 8;	 
	defparam strtchStrb40h_u7.max	= 8'h7D;//8'h64;//8'h7F;	
	//-------------------------------------------------------------------------
	CounterSeq strtchStrb40h_u7(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		.start_strb(new_cmd_strb || adma2_rdy_to_snd_dat_strb), // start the timing  	 	
		.cntr(), 
		.strb(fin_strtchStrb40h) 
	);										
	
	//-------------------------------------------------------------------------
	// We need to stretch out the snd_cmd_strb wide enough so we
	// can start the sdc_cmd_mod.  This is according to the clock control
	// register bits 15:8 (SDCLK Frequency Select).  We are using the 8-bit
	// divided clock mode.  May need different counters for different
	// SDCLK Frequency Select.  This is because different clocks need
	// different strobe length.  This particular counter is for the
	// SDCLK Freq. Select 10h.
	//-------------------------------------------------------------------------
	defparam strtchStrb10h_u9.dw 	= 8;	 
	defparam strtchStrb10h_u9.max	= 8'h20;	
	//-------------------------------------------------------------------------
	CounterSeq strtchStrb10h_u9(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		.start_strb(new_cmd_strb || adma2_rdy_to_snd_dat_strb), // start the timing  	 	
		.cntr(), 
		.strb(fin_strtchStrb10h) 
	);							 
	
	// Create a latch for snd_cmd_strb because
	// we need to stretch it out to match the
	// sdc_cmd_snd_rec sdc_clk.
	// Could possibly use a combinational?
	always@(posedge clk)
	begin
		if (reset)
			snd_cmd_strb 	<= 1'b0;
		else if (new_cmd_strb)
			snd_cmd_strb 	<= 1'b1;	// set the latch				  
			// If we're using 390 kHz sd clock.
		else if ((clock_cntrl[15:8] >> 8'h02) && fin_strtchStrb40h)
			snd_cmd_strb 	<= 1'b0;	// release the latch				  
			// If we're using 1.56 MHz sd clock.	
		else if ((clock_cntrl[15:8] << 8'h02) && fin_strtchStrb10h)
			snd_cmd_strb 	<= 1'b0;	// release the latch	
		else  // maintain latch		  	 
			snd_cmd_strb 	<= snd_cmd_strb;
	end						 
	
	// Create a latch for strt_snd_data_strb because
	// we need to stretch it out to match the
	// sdc_clk.									  
	always@(posedge clk)
	begin
		if (reset)
			strt_snd_data_strb 	<= 1'b0;
		else if (adma2_rdy_to_snd_dat_strb)
			strt_snd_data_strb 	<= 1'b1;	// set the latch				  
			// If we're using 390 kHz sd clock.
		else if ((clock_cntrl[15:8] >> 8'h02) && fin_strtchStrb40h)
			strt_snd_data_strb 	<= 1'b0;	// release the latch				  
			// If we're using 1.56 MHz sd clock.	
		else if ((clock_cntrl[15:8] << 8'h02) && fin_strtchStrb10h)
			strt_snd_data_strb 	<= 1'b0;	// release the latch	
		else  // maintain latch		  	 
			strt_snd_data_strb 	<= strt_snd_data_strb;
	end	
	
	// Create a strobe to do post response processing.
	always@(posedge clk)
	begin
		if (reset)
			post_r1_pkt_strb 	<= 1'b0;										 
			// rising edge
		else if (new_resp_pkt_strb /*&& !new_resp_pkt_strb_z1*/)							 					  
			post_r1_pkt_strb 	<= 1'b1;						  		
		else  	  	 		 	 
			post_r1_pkt_strb 	<= 1'b0;
	end								 
	
	// Create a strobe to do post response 2 processing.
	always@(posedge clk)
	begin
		if (reset)
			post_r2_pkt_strb 	<= 1'b0;										 
			// rising edge
		else if (new_resp_2_pkt_strb /*&& !new_resp_2_pkt_strb_z1*/)							 					  
			post_r2_pkt_strb 	<= 1'b1;						  		
		else  	  	 		 	 
			post_r2_pkt_strb 	<= 1'b0;
	end								 
	
	// Determine if we should enable R2 response.
	always@(posedge clk)
	begin
		if (reset)
			r2_resp_enb 	<= 1'b0;										 
			// rising edge
		else if (command[13:8] == 6'h02)							 					  
			r2_resp_enb 	<= 1'b1;						  		
		else  	  	 		 	 
			r2_resp_enb 	<= 1'b0;
	end										 
	
	// Determine RCA after reception of CMD3.
	always@(posedge clk)
	begin
		if (reset)
			rca 	<= {16{1'b0}};
			// Need to delay one clock or we'll get the previous
			// response data.
		else if ((command[13:8] == 6'h03) &&
					(!new_resp_pkt_strb_z1 && new_resp_pkt_strb_z2))							 					  
			rca 	<= response[31:16];						  		
		else  	  	 		 	 
			rca 	<= rca;
	end										
	
	sdc_cmnd_pre sdc_cmnd_pre_u8(
		.clk(clk),
   	.reset(reset),					
		.new_cmd_set_strb(new_cmd_set_strb), // ready to package the command	
		// 2.2.6 Command Register (Offset 00Eh) (pg 40)
		.command(command),
		// 2.2.4 Argument 1 Register (Offset 008h)
		.argument_1(argument_1),
		.new_cmd_strb(new_cmd_strb),
		.cmd_packet(cmd_packet),
		.cmd_crc7_out()		  	  
	);	
	
	// This is for sending command and receiving response.
	// Need to activate the sdc_clk to use this module.
   // This module will be used if you write something to
   // the Command (0x00E) register or auto cmd12 is activated.
	cmd_serial_mod cmd_serial_mod_u1(
		.sd_clk(sdc_clk),										//input	
		.reset(reset),											//input	
		.r2_resp_enb(r2_resp_enb),							//input	
		.snd_cmd_strb(snd_cmd_strb),						//input	
		.cmd_packet(cmd_packet),							//input 
		.cmd_in(cmd_in),										//input 
		.cmd_out(cmd_out),									//output
		.end_bit_det_strb(end_bit_det_strb), 			//output
		.new_resp_packet_strb(new_resp_pkt_strb), 	//output
		.new_r2_packet_strb(new_resp_2_pkt_strb),		//output
		.resp_packet(response_packet),					//output
		.resp2_packet(r2_packet)							//output
   );						
	
	// This is the ADMA2 state machine.	
	// Could use this module to start a data
	// save into the fifo in the host bus module.
	// When that is done we can start to send out
	// the data.
	adma2_fsm adma2_fsm_u2(
		.clk(clk),										                                    //                                     input 
		.reset(reset),																				   //                                     input 
      // from data_tf_using_adma_u8 module.                                                                             
		.strt_adma_strb(strt_adma_strb), 		// ready to start the transfer	                                          input 
		.continue_blk_send(continue_blk_send),												   //                                     input 
		.dat_tf_done(!dat_tf_done_z1 && dat_tf_done),									   //                                     input	
		.wr_busy(wr_busy),														 		         //                                     input	
      .des_fifo_rd_strb(des_fifo_rd_strb),                                       //                                     output
      .des_rd_data(des_rd_data),             // descriptor item                                                         input
      .adma_system_addr_strb(adma_system_addr_strb),                             //                                     output
		.adma_sar_inc_strb(adma_sar_inc_strb), 											   //                                     output
      .adma2_rdy_to_snd_dat_strb(adma2_rdy_to_snd_dat_strb),                     //                                     output
      // This strobe starts to build the fifo.
      // Another strobe will actually starts the sending.
		//.strt_fifo_strb(strt_fifo_strb)	      // start to send data to sd card.   // output
      .snd_cmd13_strb(snd_cmd13_strb),          // send cmd13 to poll for card ready
      .transfer_mode(transfer_mode),                                             //                                     input
      .fin_cmnd_strb(fin_cmnd_strb),            // finished sending out cmd13, response is ready                        input
      // need to send this command to the host bus driver
      .snd_auto_cmd12_strb(snd_auto_cmd12_strb),                                 //                                     output
      .card_rdy_bit(response[8])                // this bit holds the card status bit for card ready                    input
	);	
	
	sdc_snd_dat_1_bit sdc_snd_dat_1_bit_u10(
   	.sd_clk(sdc_clk),									//														input 
   	.reset(reset),										//														input 
       // This signal fetches the first data from the data bram.
       // It is activated when the fifo_rdy_strb is valid
		.strt_snd_data_strb(strt_snd_data_strb),	// start to send data to sd card.			input	
   	.new_dat_strb(new_dat_strb),					// Strobe for new data set of 64 bits.		output
		.sm_rd_data(sm_rd_data),						// from the system memory RAM					input	 
		.pkt_crc(pkt_crc),								// 512 bytes packet CRC.						input 
      // Finished with data transfer. but the line could still be busy because the sd card
      // is still writing the data to its memory.  Only when the card is not busy any more
      // can we start another block write if necessary.
		.dat_tf_done(dat_tf_done),						// 				                           output  
		.wr_busy(wr_busy),								// sd card is writing data to memory		output
		.D0_in(D0_in),										// Data in from sd card.						input
   	.dat_out(D0_out)									//														output
   );																													
	 
	// If rd_ram_addr is 1 or higher, send the data.							
	// The first time we read for the descriptor table,
	// the second time we read for the first data.  Continue
	// to read the data from now until we are done.  Meanwhile, the
	// adma2_fsm module will wait until we are done with the sending.
		
	// This should be right after we read back the first descriptor table.
	// The second time we use the rd_ram_addr.  The second sm_rd_data.
	// At this time, the adma2_fsm module should wait until we are done
	// with sending.
	// When done with last send, stop the adma2_fsm module.
		
	// This is for sending data.  It sends out one block of data at a time.
	// It will divide the 72 bits of data equally among D0-D3.
	// We could use the wr_busy signal to stop the adma2 from fetching
	// another data block.  When the signal is not busy any more, we
	// can continue with the next data block.
	// It will also take care of data coming back from the SD card.
//	sdc_dat_mod sdc_dat_mod_u3(
//		.sd_clk(sdc_clk),
//		.reset(reset),
//		.new_dat_set_strb(new_dat_set_strb),// ready to package the command
//		.tf_data(sm_rd_data), 					// from  
//		.dat_crc16_out(dat_crc16_out),
//		.wr_busy(/*wr_busy*/), 					// indicates that the sd card is busy
//		.D0_in(D0_in), 							// only D0 has a busy signal			 
//		.D0_out(), 									
//		.D1_in(D1_in),			  									
//		.D1_out(D1_out),
//		.D2_in(D2_in),			 
//		.D2_out(D2_out),
//		.D3_in(D3_in),			 
//		.D3_out(D3_out),		 
//		.new_rd0_pkt_strb(new_rd0_pkt_strb),
//		.rd0_pkt(rd0_pkt)
//	);		 									 
	
	// Parse CRC of DAT0.
	always@(posedge clk)
	begin
		if (reset)
			dat0_crc 	<= {16{1'b0}};
		else if (new_rd0_pkt_strb)							 					  
			dat0_crc 	<= rd0_pkt[16:1];						  		
		else  	  	 		 	 
			dat0_crc 	<= dat0_crc;
	end
	
	// We need to generate the sd_clk based on clock_cntrl.	
	// Clock needs to be on first before we can send out a command
	int_sd_clk_gen int_sd_clk_gen_u5 (
		 .clk(clk), 
		 .reset(reset), 
		 .int_clk_enb(clock_cntrl[0]), 
		 .sdclk_freq_sel(clock_cntrl[15:8]), 
		 .sd_clk_stable(sd_clk_stable), 
		 .sdc_clk(sdc_clk)
		 );
		 
	// Start generating the sdc clock when the SD Clock Enable bit in the
	// Clock Control register is turned on.  Make sure the oscillator
	// is started in the int_sd_clk_gen module. 
	//always@(posedge clk)
//	begin
//		if (reset) 
//			SDC_CLK 	<= 1'b0;
//		else if (clock_cntrl[2]) 
//			SDC_CLK 	<= sdc_clk;
//		else 
//			SDC_CLK 	<= 1'b0;
//	end				  
  	assign SDC_CLK	=	clock_cntrl[2] ? ~sdc_clk : 1'b0;
	////////////////////////////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	
	
endmodule
