`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:37:10 12/04/2012 
// Design Name: 
// Module Name:    card_init_and_id 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		Section 3.6 Card Initialization and Identification
//							of the SD Host Controller Simplified Specification
//							Version 3.00. (page 100)
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module card_init_and_id(
   input 					clk,
   input 					reset,
	input 					start_strb,	
	// finished sending out command to sd card
	input						end_bit_det_strb,	
	
	// next 6 ports for host controller register map
	output		[11:0]	rd_reg_index,
	input 		[127:0]	rd_reg_input,
	output					wr_reg_strb,
	output		[11:0]	wr_reg_index,
	output 		[31:0]	wr_reg_output,
	output 		[2:0]		reg_attr,
	 
	// stand by state indicates the card is ready to be communicated
	output					stby_strb,
	output					not_int_strb, 	// can't initialize card
	output		[127:0]	cid_out,												
	output reg	[15:0]	rca,
	output					card_init_proc	// indicates we are still in this module
   );

	// Registers
	// Next seven registers are for the host controller reg. map
	reg	[11:0]	rd_reg_index_int; // for this module own reading
	reg 	[11:0] 	rd_reg_index_reg;	// for this module own reading
	reg 	[11:0] 	rd_reg2_index_reg;// for this module own reading
	reg	[11:0]	rd_reg_indx;		// to assign to output
	reg				issue_sd_cmd_strb;
	reg	[5:0]		cmd_index;
	reg	[31:0] 	argument;
	reg	[1:0]		command_type;
	reg				data_pres_select;
	reg	[1:0]		resp_type_select;
	reg				issue_cmd_when_busy;
	reg				issue_abort_cmd;
	reg				r7_crc7_good;
	reg				f8_flg;
	reg				cmd8_no_resp;
	reg	[3:0]		try_cnt; 			// how many time have we tried cmd8
	reg				try_cmd8_again; 	// try cmd8 one more time
	reg				unuse_crd_flg; 	// unusuable card flag
	reg				cmd5_no_resp; 		// no response for cmd5
	//reg				sdio_flg; 			// sdio card or not
	reg				app_cmd; 			// app_cmd enalbed if 1 from sd card
	reg				try_cmd55_again;	// try cmd55 again, amount can be set
	reg				ocr_ok;				// ocr of acmd41
	//reg	[15:0]	vdd_volt_wind;		// get back from acmd41 query
	reg				init_resp_ok;		// initialization resp. okay
	reg				card_busy;			// check if card is busy	 
	reg				card_busy_z1;			// delay
	reg				card_ccs;			// ccs = 1 means sdhc or sdxc
	reg	[127:0]	cid;
	reg				init_acmd41_flg;
	reg				rca_state_cnt;		// counts how many time we try to read RCA.
	reg				rca_valid;			// RCA is valid.
	// indicates card is in standby mode, ready to be communicated
	reg				stby_strb_reg;			
	// needed if 2nd input is necessary
	reg				rd_input_strb;
	reg				vca_good;
	reg				chk_pat_good;
	reg				card_init_proc_reg;	// indicates we are still in this module
	reg				not_int_strb_reg; 	// card can't be initialized	 
	reg				one_sec_tout_strt_strb; // start the timeout for acmd41
	reg				bsy_bit_to; 				// busy bit timeout latch for acmd41
	reg				strt_resnd_wt_strb; 		// start the resend counter	
	
	// Wires
	wire				fin_cmnd_strb;
	//wire				err_stat;
	//wire	[1:0]		gen4ClksCnt;
	wire				one_sec_tout;			// 1 sec. timeout for acmd41 cmd.
	//wire	[7:0]		oneSecToutCnt;
	//wire				rd_2nd_input_strb;
	wire	[11:0]	rd_reg_index_iss;		// for issue_sd_cmd
	wire				wr_reg_strb_iss;  	// for issue_sd_cmd
	wire	[11:0]	wr_reg_index_iss;		// for issue_sd_cmd
	wire 	[31:0]	wr_reg_output_iss;	// for issue_sd_cmd
	wire 	[2:0]		reg_attr_iss;			// for issue_sd_cmd
	wire	[11:0]	rd_reg_index_fin;		// for fin_a_cmnd
	wire				wr_reg_strb_fin;  	// for fin_a_cmnd
	wire	[11:0]	wr_reg_index_fin;		// for fin_a_cmnd
	wire 	[31:0]	wr_reg_output_fin;	// for fin_a_cmnd
	wire 	[2:0]		reg_attr_fin;			// for fin_a_cmnd
	// indicates that issue_sd_cmd.v is being used.
	wire				iss_sd_cmd_proc;
	// indicates that fin_a_cmnd.v is being used.
	wire				fin_a_cmd_proc;
	// We need a few clocks to read the registers from the
	// host controller.
	wire				read_clks_tout;			
	wire 				strt_resnd;	// start to resend command amcd41.
	
	// Initialize sequential logic
	initial			
	begin
		rd_reg_index_int			<= 12'h000;
		rd_reg_index_reg			<= 12'h000;
		rd_reg2_index_reg			<= 12'h010;
		rd_reg_indx					<= 12'h010;
		issue_sd_cmd_strb			<= 1'b0;
		cmd_index					<= {6{1'b0}};
		argument						<= {32{1'b0}};
		command_type				<= {2{1'b0}};
		data_pres_select			<= 1'b0;
		resp_type_select			<= {2{1'b0}};
		issue_cmd_when_busy		<= 1'b0;
		issue_abort_cmd			<= 1'b0;
		r7_crc7_good				<= 1'b0;
		f8_flg						<= 1'b0;
		cmd8_no_resp				<= 1'b0;
		try_cnt						<= {4{1'b0}};
		try_cmd8_again				<= 1'b0;
		unuse_crd_flg				<=	1'b0;
		cmd5_no_resp				<= 1'b0;
		//sdio_flg					<=	1'b0;
		app_cmd						<=	1'b0;
		try_cmd55_again			<= 1'b0;
		ocr_ok						<= 1'b0;
		//vdd_volt_wind			<= {16{1'b0}};
		init_resp_ok				<= 1'b0;
		card_busy					<= 1'b1; // start off busy
		card_busy_z1				<= 1'b1; // start off busy
		card_ccs						<= 1'b0;
		cid							<= {128{1'b0}}; 
		rca							<= {16{1'b0}};
		init_acmd41_flg			<= 1'b0;
		rca_state_cnt				<= 1'b0;
		rca_valid					<= 1'b0;
		stby_strb_reg				<= 1'b0;
		vca_good						<= 1'b0;
		chk_pat_good				<= 1'b0;
		card_init_proc_reg		<= 1'b0;
		not_int_strb_reg			<= 1'b0;
		one_sec_tout_strt_strb	<= 1'b0;	
		bsy_bit_to					<= 1'b0;	  
		strt_resnd_wt_strb		<= 1'b0;
	end
	
	// Assign wires or registers to outputs.
   assign wr_reg_strb   	= iss_sd_cmd_proc ? wr_reg_strb_iss   : wr_reg_strb_fin;
   assign wr_reg_index  	= iss_sd_cmd_proc ? wr_reg_index_iss  : wr_reg_index_fin;
   assign wr_reg_output 	= iss_sd_cmd_proc ? wr_reg_output_iss : wr_reg_output_fin;
   assign reg_attr      	= iss_sd_cmd_proc ? reg_attr_iss      : reg_attr_fin;
	assign rd_reg_index		= rd_reg_indx;
	assign stby_strb			= stby_strb_reg;
	assign card_init_proc 	= card_init_proc_reg;
	assign not_int_strb	 	= not_int_strb_reg;
	assign cid_out				= cid;
	
	// We'll time when to read the second input if necessary.
	// The second input uses rd_reg2_index_reg.
//	assign rd_reg_index_int		= rd_2nd_input_strb ? rd_reg2_index_reg : 
//																 rd_reg_index_reg;											
	
	// Create Delays
	always@(posedge clk)
	begin
		if (reset)																							
			card_busy_z1	<= 1'b1; // start off busy
		else 																																	
			card_busy_z1	<= card_busy; 
	end											
	
	// Decide which rd_reg_index to use internal to this module.
	always@(posedge clk)
	begin
		if (reset)
			rd_reg_index_int	<= 12'h000; 	// only when reading the second input
//		else if (rd_2nd_input_strb)
//			rd_reg_index_int	<= rd_reg2_index_reg;
		else 
			rd_reg_index_int	<= rd_reg_index_reg;
	end
	
	// Decide which rd_reg_index to select.  Both internal and external.
//	always@(posedge clk)
//	begin
//		if (reset) begin
//			sel_rd_reg_indx	<= 2'b00; 		
//		end
//		else if (iss_sd_cmd_proc) begin
//			sel_rd_reg_indx	<= 2'b01;
//		end
//		else if (fin_a_cmd_proc) begin
//			sel_rd_reg_indx	<= 2'b10;
//		end
//		else begin
//			sel_rd_reg_indx	<= 2'b00; // default for internal readings
//		end
//	end
//	
	// Decide which rd_reg_index to use with host controller.
//   always @(sel_rd_reg_indx, rd_reg_index_int, rd_reg_index_iss, 
//				rd_reg_index_fin)
//      case (sel_rd_reg_indx)
//         2'b00: rd_reg_indx = rd_reg_index_int; // has two options
//         2'b01: rd_reg_indx = rd_reg_index_iss;
//         2'b10: rd_reg_indx = rd_reg_index_fin;
//      endcase	
	
	//Decide which rd_reg_index to select.  Both internal and external.
	always@(posedge clk)
	begin
		if (reset)
			rd_reg_indx	<= 12'h010;
		else if (iss_sd_cmd_proc)
			rd_reg_indx <= rd_reg_index_iss;
		else if (fin_a_cmd_proc)
			rd_reg_indx <= rd_reg_index_fin;
		else 
			rd_reg_indx <= rd_reg_index_int; // default for internal readings
	end
	
	// State machine for card initialization and identification.
   parameter state_start  							= 36'b0000_0000_0000_0000_0000_0000_0000_0000_0001;
   parameter state_rst_crd  						= 36'b0000_0000_0000_0000_0000_0000_0000_0000_0010;
   parameter state_rst_crd_wt  					= 36'b0000_0000_0000_0000_0000_0000_0000_0000_0100;
   parameter state_volt_chk  						= 36'b0000_0000_0000_0000_0000_0000_0000_0000_1000;
   parameter state_volt_chk_wt  					= 36'b0000_0000_0000_0000_0000_0000_0000_0001_0000;
   parameter state_chk_resp  						= 36'b0000_0000_0000_0000_0000_0000_0000_0010_0000;
   parameter state_chk_resp_wt  					= 36'b0000_0000_0000_0000_0000_0000_0000_0100_0000;
  	parameter state_snd_cmd_55						= 36'b0000_0000_0000_0000_0000_0000_0000_1000_0000;
  	parameter state_snd_cmd_55_wt					= 36'b0000_0000_0000_0000_0000_0000_0001_0000_0000;
  	parameter state_cmd_55_resp					= 36'b0000_0000_0000_0000_0000_0000_0010_0000_0000;
  	parameter state_cmd_55_resp_wt				= 36'b0000_0000_0000_0000_0000_0000_0100_0000_0000;
	parameter state_get_ocr_acmd41_f81			= 36'b0000_0000_0000_0000_0000_0000_1000_0000_0000;
	parameter state_get_ocr_acmd41_f81_wt		= 36'b0000_0000_0000_0000_0000_0001_0000_0000_0000;
	parameter state_chk_ocr_acmd41				= 36'b0000_0000_0000_0000_0000_0010_0000_0000_0000;
	parameter state_chk_ocr_acmd41_wt			= 36'b0000_0000_0000_0000_0000_0100_0000_0000_0000;
	parameter state_init_acmd41					= 36'b0000_0000_0000_0000_0000_1000_0000_0000_0000;
	parameter state_init_acmd41_wt				= 36'b0000_0000_0000_0000_0001_0000_0000_0000_0000;
	parameter state_resp_ok_22						= 36'b0000_0000_0000_0000_0010_0000_0000_0000_0000;
	parameter state_resp_ok_22_wt					= 36'b0000_0000_0000_0000_0100_0000_0000_0000_0000;
   parameter state_chk_busy_23 	 				= 36'b0000_0000_0000_0000_1000_0000_0000_0000_0000;
   parameter state_chk_busy_23_wt 	 			= 36'b0000_0000_0000_0001_0000_0000_0000_0000_0000;
   parameter state_chk_ccs							= 36'b0000_0000_0000_0010_0000_0000_0000_0000_0000;
   parameter state_chk_ccs_wt						= 36'b0000_0000_0000_0100_0000_0000_0000_0000_0000;
	parameter state_sdsc_ver2						= 36'b0000_0000_0000_1000_0000_0000_0000_0000_0000;
	parameter state_sdhc_sdxc						= 36'b0000_0000_0001_0000_0000_0000_0000_0000_0000;
	parameter state_sig_volt_sw_proc				= 36'b0000_0000_0010_0000_0000_0000_0000_0000_0000;
	parameter state_get_cid							= 36'b0000_0000_0100_0000_0000_0000_0000_0000_0000;
	parameter state_get_cid_wt						= 36'b0000_0000_1000_0000_0000_0000_0000_0000_0000;
	parameter state_chk_cid_resp					= 36'b0000_0001_0000_0000_0000_0000_0000_0000_0000;
	parameter state_get_rca							= 36'b0000_0010_0000_0000_0000_0000_0000_0000_0000;
	parameter state_get_rca_wt						= 36'b0000_0100_0000_0000_0000_0000_0000_0000_0000;
	parameter state_chk_rca_resp					= 36'b0000_1000_0000_0000_0000_0000_0000_0000_0000;
	parameter state_chk_rca_resp_wt				= 36'b0001_0000_0000_0000_0000_0000_0000_0000_0000;
	parameter state_wt_bf_resnd_init_acmd41	= 36'b0010_0000_0000_0000_0000_0000_0000_0000_0000;
	parameter state_stby								= 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000;
	parameter state_end								= 36'b1000_0000_0000_0000_0000_0000_0000_0000_0000;
   (* FSM_ENCODING="ONE-HOT", SAFE_IMPLEMENTATION="YES", 
	SAFE_RECOVERY_STATE="state_start" *) 
	reg [35:0] state = state_start;

   always@(posedge clk)
      if (reset) begin
         state 							<= state_start;
         //<outputs> <= <initial_values>;
			rd_input_strb					<= 1'b0;
			rd_reg_index_reg 				<= 12'h000;
			rd_reg2_index_reg				<= 12'h000;
			issue_sd_cmd_strb				<= 1'b0;
			cmd_index						<= {6{1'b0}};
			argument							<= {32{1'b0}};
			command_type					<= {2{1'b0}};
			data_pres_select				<= 1'b0;
			resp_type_select				<= {2{1'b0}};
			issue_cmd_when_busy			<= 1'b0;
			issue_abort_cmd				<= 1'b0;
			try_cnt							<= {4{1'b0}};
			try_cmd8_again					<= 1'b0;
			unuse_crd_flg					<=	1'b0;
			try_cmd55_again				<= 1'b0;
			init_acmd41_flg				<= 1'b0;	  
			strt_resnd_wt_strb			<= 1'b0;
			rca_state_cnt					<= 1'b0; 		
			stby_strb_reg					<= 1'b0;
			card_init_proc_reg			<= 1'b0;
      end
      else
         (* PARALLEL_CASE *) case (state)			
            state_start : begin				  // 36'b0000_0000_0000_0000_0000_0000_0000_0000_0001
               if (start_strb)
                  state 				<= state_volt_chk; //state_rst_crd;
               else if (!start_strb)
                  state 				<= state_start;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b0;
            end
            state_rst_crd : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_0000_0010
               state 					<= state_rst_crd_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;		// send a command
					cmd_index				<= 6'h00; 	// cmd0
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= try_cmd8_again;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_rst_crd_wt : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_0000_0100
               if (fin_cmnd_strb)
                  state 				<= state_volt_chk;
               else if (!fin_cmnd_strb)
                  state 				<= state_rst_crd_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;		
					cmd_index				<= 6'h00; 	// cmd0
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= try_cmd8_again;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_volt_chk : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_0000_1000
               state 					<= state_volt_chk_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;
					cmd_index				<= 6'h08; // cmd8, has vhs and chk pattern
					argument					<= {{20{1'b0}},4'h1,8'hAA};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= 2'b10;
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= try_cmd8_again;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_volt_chk_wt : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_0001_0000
               if (fin_cmnd_strb)
                  state 				<= state_chk_resp;
               else if (!fin_cmnd_strb)
                  state 				<= state_volt_chk_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= 6'h08; // cmd8, has vhs and chk pattern
					argument					<= {{20{1'b0}},4'h1,8'hAA};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= 2'b10;
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= try_cmd8_again;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_chk_resp : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_0010_0000	
//				Voltage check command enables the Hosts to support future low 
//				voltage specification. However, at this time, only one voltage 
//				is defined. Legacy cards and Not SD cards do not respond to CMD8.
//				In this case, set F8 to 0 (F8 is CMD8 valid flag used in step (11))
//				and go to Step (5). Only Version 2.00 or higher cards can respond to 
//				CMD8. The host needs to check whether CRC of the response is valid 
//				and whether VHS and check pattern in the argument are equal to VCA 
//				and check pattern in the response. Passing all these checks
//				results in CMD8 response OK. In this case, set F8 to 1 and go to 
//				step (5). If one of the checks is failed, go to step (4).  
//				See page 100.
//				We will not check for CRC, assume it is okay.  We can check for VCA
// 			and echo pattern.  We will stream line the initialization process.
//				Therefore, we will only need to read register 010h.
               state 					<= state_chk_resp_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1; 
					rd_reg_index_reg 		<= 12'h010;	// response reg.
					rd_reg2_index_reg		<= 12'h000; 
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}}; 
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					// Only try 1 time.
					try_cmd8_again			<=	1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_chk_resp_wt : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_0100_0000
               if (read_clks_tout && f8_flg) 
                  state 				<= state_snd_cmd_55;
               else if (!read_clks_tout) 
                  state 				<= state_chk_resp_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0; 
					rd_reg_index_reg 		<= 12'h010;	// response reg.
					rd_reg2_index_reg		<= 12'h000; 
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}}; 
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					// Only try 1 time.
					try_cmd8_again			<=	1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
				// We need to send cmd55 before be can send
				// acmd41.
            state_snd_cmd_55 : begin	// 36'b0000_0000_0000_0000_0000_0000_0000_1000_0000
               state 					<= state_snd_cmd_55_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;
					cmd_index				<= 6'h37; // cmd55
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= init_acmd41_flg;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_snd_cmd_55_wt : begin	// 36'b0000_0000_0000_0000_0000_0000_0001_0000_0000
               if (fin_cmnd_strb)
                  state 				<= state_cmd_55_resp;
               else if (!fin_cmnd_strb)
                  state 				<= state_snd_cmd_55_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= 6'h37; // cmd55
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= init_acmd41_flg; 		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_cmd_55_resp : begin	// 36'b0000_0000_0000_0000_0000_0000_0010_0000_0000
               state 					<= state_cmd_55_resp_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // read resp. reg.
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt + 1'b1;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;				
					// We will stop trying after three times
					// if we don't get the app_cmd bit from command 55.
					try_cmd55_again		<= (((try_cnt < 4) && !app_cmd)? 
													1'b1 : 1'b0);
					init_acmd41_flg		<= init_acmd41_flg; 		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_cmd_55_resp_wt : begin	// 36'b0000_0000_0000_0000_0000_0000_0100_0000_0000
               if (read_clks_tout && app_cmd && (!init_acmd41_flg))
						// For query only.
                  state 				<= state_get_ocr_acmd41_f81;
               else if (read_clks_tout && app_cmd && init_acmd41_flg)
						// If we need to start the acmd41 for initialization
						// go to the state_init_acmd41 state.
                  state 				<= state_init_acmd41;
               else if (read_clks_tout && (!app_cmd) && try_cmd55_again)
						// Keep sending cmd55 a few times
						// until we get the app_cmd bit from the
						// sd card.
                  state 				<= state_snd_cmd_55;
               else if (read_clks_tout && (!app_cmd) && try_cnt == 4'h4)
						// If we have tried for three times and
						// we did not get app_cmd, we'll end the
						// sequence.
                  state 				<= state_end;
               else if (!read_clks_tout)
                  state 				<= state_cmd_55_resp_wt;
               else
                  state 				<= state_end;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // read resp. reg.
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					// Keep trying if we haven't got an app_cmd bit
					// for 3 times.
					try_cmd55_again		<= try_cmd55_again;
					init_acmd41_flg		<= init_acmd41_flg;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_get_ocr_acmd41_f81 : begin	// 36'b0000_0000_0000_0000_0000_0000_1000_0000_0000
					state 					<= state_get_ocr_acmd41_f81_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;
					cmd_index				<= 6'h29; 		// acmd41 cmd
					argument					<= {32{1'b0}}; // inquiry for ocr, no data
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_get_ocr_acmd41_f81_wt : begin	// 36'b0000_0000_0000_0000_0000_0001_0000_0000_0000
					if (fin_cmnd_strb) 
                  state 				<= state_chk_ocr_acmd41;
               else if (!fin_cmnd_strb)
                  state 				<= state_get_ocr_acmd41_f81_wt;
               else
						state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= 6'h29; 		// acmd41 cmd
					argument					<= {32{1'b0}}; // inquiry for ocr, no data
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_chk_ocr_acmd41 : begin	// 36'b0000_0000_0000_0000_0000_0010_0000_0000_0000
               state 					<= state_chk_ocr_acmd41_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // response reg.
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// If ocr is okay then after we send cmd55,
					// we'll go to state_init_acmd41.  That's why
					// we need to set this bit to one.
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0;	 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_chk_ocr_acmd41_wt : begin	// 36'b0000_0000_0000_0000_0000_0100_0000_0000_0000
               if (read_clks_tout && ocr_ok)
                  state 				<= state_snd_cmd_55;
						// if ocr is not okay, we'll end the sequence
               else if (read_clks_tout && (!ocr_ok))
                  state 				<= state_end;
						// if ocr is not okay, we'll end the sequence
               else if (!read_clks_tout)
                  state 				<= state_chk_ocr_acmd41_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // response reg.
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// If ocr is okay then after we send cmd55,
					// we'll go to state_init_acmd41.  That's why
					// we need to set this bit to one.
					init_acmd41_flg		<= 1'b1;			  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0;	 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_init_acmd41 : begin	// 36'b0000_0000_0000_0000_0000_1000_0000_0000_0000
               state 					<= state_init_acmd41_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;
					cmd_index				<= 6'h29; // acmd41
					// need to set up argument
					// determine ocr from the first acmd41 command.
					argument					<= {8'h40,16'h0080,{8{1'b0}}}; 
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_init_acmd41_wt : begin	// 36'b0000_0000_0000_0000_0001_0000_0000_0000_0000
               if (fin_cmnd_strb)
                  state 				<= state_resp_ok_22;
               else if (!fin_cmnd_strb)
                  state 				<= state_init_acmd41_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= 6'h29; // acmd41
					// need to set up argument
					// determine ocr from the first acmd41 command.
					argument					<= {8'h40,16'h0080,{8{1'b0}}}; 
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_resp_ok_22 : begin	// 36'b0000_0000_0000_0000_0010_0000_0000_0000_0000
               state 					<= state_resp_ok_22_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_resp_ok_22_wt : begin	// 36'b0000_0000_0000_0000_0100_0000_0000_0000_0000
               if (read_clks_tout && init_resp_ok)
                  state 				<= state_chk_busy_23;
               else if (read_clks_tout && (!init_resp_ok))
                  state 				<= state_end;
               else if (!read_clks_tout)
                  state 				<= state_resp_ok_22_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_chk_busy_23 : begin	// 36'b0000_0000_0000_0000_1000_0000_0000_0000_0000
               state 					<= state_chk_busy_23_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;
					// Start to wait for 20 ms before we send
					// another acmd41.
					strt_resnd_wt_strb	<= 1'b1;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1; 
            end
            state_chk_busy_23_wt : begin	// 36'b0000_0000_0000_0001_0000_0000_0000_0000_0000
               if (read_clks_tout && card_busy && (!bsy_bit_to))
						// If card is still busy, keep checking if
						// we haven't timeout yet.
                  state 				<= state_wt_bf_resnd_init_acmd41;
               else if (read_clks_tout && (!card_busy))
                  state 				<= state_chk_ccs;
               else if (read_clks_tout && card_busy && bsy_bit_to)
						// If still busy and 1 sec is up
						// exit the state machine.
                  state 				<= state_end;
               else if (!read_clks_tout)
                  state 				<= state_chk_busy_23_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1; 
            end
            state_chk_ccs : begin	// 36'b0000_0000_0000_0010_0000_0000_0000_0000_0000
               state 					<= state_chk_ccs_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
				end
            state_chk_ccs_wt : begin	// // 36'b0000_0000_0000_0100_0000_0000_0000_0000_0000
               if (read_clks_tout && card_ccs)
						// If ccs, card is high capacity.
                  state 				<= state_sdhc_sdxc;
						// If not ccs, card is standard capacity.
               else if (read_clks_tout && (!card_ccs))
                  state 				<= state_sdsc_ver2;
               else if (!read_clks_tout)
                  state 				<= state_chk_ccs_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
				end
            state_sdsc_ver2 : begin	// 36'b0000_0000_0000_1000_0000_0000_0000_0000_0000
               state 					<= state_get_cid;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000; 
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1; 
				end
            state_sdhc_sdxc : begin	// 36'b0000_0000_0001_0000_0000_0000_0000_0000_0000
               state 					<= state_sig_volt_sw_proc;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000; 
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0;	 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
				end
            state_sig_volt_sw_proc : begin	// 36'b0000_0000_0010_0000_0000_0000_0000_0000_0000
					// We're mot implimenting signal voltage switch.
					// We can do this in the future to accomodate
					// ultra high speed card.
               state 					<= state_get_cid;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000; 
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0;	 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
				end
            state_get_cid : begin	// 36'b0000_0000_0100_0000_0000_0000_0000_0000_0000
               state 					<= state_get_cid_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;
					cmd_index				<= 6'h02; // cmd2
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= 2'b10;
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= 1'b0;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            state_get_cid_wt : begin	// 36'b0000_0000_1000_0000_0000_0000_0000_0000_0000
               if (fin_cmnd_strb)
                  state 				<= state_chk_cid_resp;
               else if (!fin_cmnd_strb)
                  state 				<= state_get_cid_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= 6'h02; // cmd2
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= 2'b10;
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= 1'b0;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
				state_chk_cid_resp : begin	// 36'b0000_0001_0000_0000_0000_0000_0000_0000_0000
					// Go straight to next state, we don't need to check.
					// We need this state just to fill up the cid register.
					state 					<= state_get_rca;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // read response register
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= rca_state_cnt; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
				state_get_rca : begin	// 36'b0000_0010_0000_0000_0000_0000_0000_0000_0000
               state 					<= state_get_rca_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b1;
					cmd_index				<= 6'h03; // cmd3
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= 2'b10;
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= 1'b0;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= rca_state_cnt + 1'b1; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
				state_get_rca_wt : begin	// 36'b0000_0100_0000_0000_0000_0000_0000_0000_0000
               if (fin_cmnd_strb)
                  state 				<= state_chk_rca_resp;
               else if (!fin_cmnd_strb)
                  state 				<= state_get_rca_wt;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= 6'h03; // cmd3
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= 2'b10;
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= 1'b0;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= rca_state_cnt; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
				state_chk_rca_resp : begin	// 36'b0000_1000_0000_0000_0000_0000_0000_0000_0000
					state 					<= state_chk_rca_resp_wt;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b1;
					rd_reg_index_reg 		<= 12'h010; // read response register
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= rca_state_cnt; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
				state_chk_rca_resp_wt : begin	// 36'b0001_0000_0000_0000_0000_0000_0000_0000_0000
					if (read_clks_tout && rca_valid)
						state 				<= state_stby;
					else if (read_clks_tout && (!rca_valid) && (rca_state_cnt << 2)) // try two times
						state 				<= state_get_rca;
					else if (!read_clks_tout)
						state 				<= state_chk_rca_resp_wt;
					else
						state 				<= state_end;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // read response register
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= rca_state_cnt; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end		
				// Wait for less than 50 ms before we resend
				// another amcd41 initialization command.
				state_wt_bf_resnd_init_acmd41 : begin	// 36'b0010_0000_0000_0000_0000_0000_0000_0000_0000
               if (strt_resnd)
                  state 				<= state_snd_cmd_55;
               else if (!strt_resnd)
                  state 				<= state_wt_bf_resnd_init_acmd41;
               else
                  state 				<= state_start;
               //<outputs> <= <values>;			  		  
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // resp. reg
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= try_cnt;
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					// make sure we go to initialization
					init_acmd41_flg		<= 1'b1;			  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0;	 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1; 
            end													 
				state_stby : begin	// 36'b0100_0000_0000_0000_0000_0000_0000_0000_0000 
					state 					<= state_end;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h010; // read response register
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= rca_state_cnt; 		
					stby_strb_reg			<= 1'b1;
					card_init_proc_reg	<= 1'b1;
            end		
				state_end : begin	// 36'b1000_0000_0000_0000_0000_0000_0000_0000_0000
               state 					<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	unuse_crd_flg;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b1;
            end
            default: begin  // Fault Recovery
               state 					<= state_start;
               //<outputs> <= <values>;
					rd_input_strb			<= 1'b0;
					rd_reg_index_reg 		<= 12'h000;
					rd_reg2_index_reg		<= 12'h000;
					issue_sd_cmd_strb		<= 1'b0;
					cmd_index				<= {6{1'b0}};
					argument					<= {32{1'b0}};
					command_type			<= {2{1'b0}};
					data_pres_select		<= 1'b0;
					resp_type_select		<= {2{1'b0}};
					issue_cmd_when_busy	<= 1'b0;
					issue_abort_cmd		<= 1'b0;
					try_cnt					<= {4{1'b0}};
					try_cmd8_again			<= 1'b0;
					unuse_crd_flg			<=	1'b0;
					try_cmd55_again		<= 1'b0;
					init_acmd41_flg		<= 1'b0;		  
					strt_resnd_wt_strb	<= 1'b0;
					rca_state_cnt			<= 1'b0; 		
					stby_strb_reg			<= 1'b0;
					card_init_proc_reg	<= 1'b0;
				end
			endcase

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
		.start_strb(rd_input_strb),   	 	
		.cntr(), 
		.strb(read_clks_tout) 
	);
	
	// The two modules below take care of all the communication
	// with the host controller.  Issue_sd_cmd initiate comm. with
	// the SD Card and talks to the host controller memory map.  
	// Fin_a_cmnd only talks to the host controller memory map 
	// to do some clean up.
	// Instantiate the module
	issue_sd_cmd issue_sd_cmd_u6 (
		.clk(clk), 
		.reset(reset), 			
		// wait two clocks so we have time to parse out the
		// necessary information from data input from the host.
		.issue_sd_cmd_strb(issue_sd_cmd_strb), 
		.cmd_index(cmd_index), 						// See 2.2.6 Command Reg. (00Eh)
		.argument(argument), 
		.command_type(command_type), 				// See 2.2.6 Command Reg. (00Eh) 
		.data_pres_select(data_pres_select), 	// See 2.2.6 Command Reg. (00Eh)
		// Need to determine the next two inputs.
		.cmd_indx_chk_enb(1'b0/*cmd_indx_chk_enb*/),	// See 2.2.6 Command Reg. (00Eh) 
		.cmd_crc_chk_enb(1'b0/*cmd_crc_chk_enb*/), 	// See 2.2.6 Command Reg. (00Eh)
		.resp_type_select(resp_type_select), 	// See 2.2.6 Command Reg. (00Eh)
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
		 
	// Instantiate the module
	fin_a_cmnd fin_a_cmnd_u2 (
		.clk(clk), 
		.reset(reset), 
		.fin_a_cmd_strb(fin_a_cmd_strb), 
		.cmd_index(cmd_index), 
		.cmd_with_tf_compl_int(1'b0), 
		.end_bit_det_strb(end_bit_det_strb),	// finished sending out command
		
		.rd_reg_index(rd_reg_index_fin), 
		.rd_reg_input(rd_reg_input), 
		.wr_reg_strb(wr_reg_strb_fin), 
		.wr_reg_index(wr_reg_index_fin), 
		.wr_reg_output(wr_reg_output_fin), 
		.reg_attr(reg_attr_fin), 

		//.resp_reg_data(resp_reg_data), // from Response register (010h)
		.err_int_stat(/*err_stat*/), 
		.fin_a_cmd_proc(fin_a_cmd_proc),
		.fin_cmnd_strb(fin_cmnd_strb)
		);
	
	//-------------------------------------------------------------------------
	// We need a generic 4 clocks counter to get a second register read from
	// the map register.  We do this rather than have two read registers
	// from the host controller.
	//-------------------------------------------------------------------------
//	defparam gen4ClksCntr_u3.dw 	= 2;
//	// Change this to reflect the number of counts you want.
//	defparam gen4ClksCntr_u3.max	= 2'h3;	
//	//-------------------------------------------------------------------------
//	CounterSeq gen4ClksCntr_u3(
//		.clk(clk), 		// Clock input 50 MHz 
//		.reset(reset),	// GSR
//		.enable(1'b1), 	
//		.start_strb(rd_input_strb), // strobe when read 1st input.
//		.cntr(/*gen4ClksCnt*/), 
//		.strb(rd_2nd_input_strb) // output
//	);

	//-------------------------------------------------------------------------
	// We need a 1 second time out for acmd41 initialization cmd.
	//-------------------------------------------------------------------------
	defparam oneSecToutCntr_u4.dw 	= 28;
	// Make sure this reflect 1 second when you are ready to finalize the
	// design.
	defparam oneSecToutCntr_u4.max	= 28'h04C4B40;//28'h0989680;//28'h2FAF080; // 1 sec.	
	//-------------------------------------------------------------------------
	CounterSeq oneSecToutCntr_u4(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(one_sec_tout_strt_strb),   	 	
		.cntr(/*oneSecToutCnt*/), 
		.strb(one_sec_tout) 
	);	
	
	// Start the one second timeout the first time we check command acmd41 for
	// the busy signal.  It may not be a good idea to rely on the try_cnt
	// condition.  It was created to monitor cmd 55.  May need to consider
	// something else.
	always@(posedge clk)
	begin
		if (reset) 
			one_sec_tout_strt_strb	<= 1'b0;		
		else if ((try_cnt == 4'h2) && (state == state_chk_busy_23)) 
			one_sec_tout_strt_strb	<= 1'b1;
		else 
			one_sec_tout_strt_strb	<= 1'b0;
	end							
	
	// Latch the timeout for the busy bit from acmd41.
	always@(posedge clk)
	begin
		if (reset) 
			bsy_bit_to	<= 1'b0;		
		else if (one_sec_tout) 
			bsy_bit_to	<= 1'b1;
		// If card is no longer busy or we're back at start, release latch
		else if ((!card_busy && card_busy_z1) || (state == state_start)) 
			bsy_bit_to	<= 1'b0;
		else 
			bsy_bit_to	<= bsy_bit_to;
	end

	//-------------------------------------------------------------------------
	// We need to wait less than 50 ms before we resend the acmd41 command.
	// Becarefuly, we may not need to use this strobe after this counter
	// is started.	 We only needed if we need to resend another acmd41 command.
	//-------------------------------------------------------------------------
	defparam rsndCntr.dw 	= 28;
	// Make sure this reflect the right time when you are ready to finalize the
	// design.
	defparam rsndCntr.max	= 28'h00F4240;//28'h2FAF080; // 1 sec.	
	//-------------------------------------------------------------------------
	CounterSeq rsndCntr(
		.clk(clk), 		// Clock input 50 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start the timing
		.start_strb(strt_resnd_wt_strb),   	 	
		.cntr(/*oneSecToutCnt*/), 
		.strb(strt_resnd) 
	);	
	
	// Check VCA for CMD8 (voltage good), Response Register (Offset 010h).
	always@(posedge clk)
	begin
		if (reset) 
			vca_good	<= 1'b0;		
		else if (rd_reg_input[11:8] == 4'h1) 
			vca_good	<= 1'b1;
		else 
			vca_good	<= 1'b0;
	end
	
	// Check check-pattern for CMD8, becareful, other registers are written to 
	// rd_reg_input.  Response Register (Offset 010h).
	always@(posedge clk)
	begin
		if (reset)
			chk_pat_good	<= 1'b0;		
		else if (rd_reg_input[7:0] == 8'hAA) 
			chk_pat_good	<= 1'b1;
		else 
			chk_pat_good	<= 1'b0;
	end
	
	// Check check-pattern for CMD8, becareful, other registers are written to 
	// rd_reg_input.  Response Register (Offset 010h).
	// If we don't get the check pattern for command 08h then we don't have 
	// a sdhc card.
	always@(posedge clk)
	begin
		if (reset)
			cmd8_no_resp	<= 1'b0;
		// If check pattern is h00, we'll know that we don't have
		// any response.
		else if (rd_reg_input[7:0] == 8'h00) 
			cmd8_no_resp	<= 1'b1;
		else 
			cmd8_no_resp	<= 1'b0;
	end		
	
	// Check CRC7 for CMD8 response, becareful, other registers are written to 
	// rd_reg_input.  Response Register (Offset 032h).
	// We'll check this first before we check for the f8_flg.
//	always@(posedge clk)
//	begin
//		if (reset) 
//			r7_crc7_good	<= 1'b0; 
//		else if (!rd_reg_input[1]) // no command crc error
//			r7_crc7_good	<= 1'b1;
//		else 
//			r7_crc7_good	<= 1'b0;
//	end
	
	// Check F8 flag for CMD8.
	always@(posedge clk)
	begin
		if (reset) 
			f8_flg	<= 1'b0;
		else if (vca_good && chk_pat_good)
			f8_flg	<= 1'b1;
		else 
			f8_flg	<= 1'b0;
	end
	
	// Check OCR for CMD5, becareful, other registers are written to 
	// rd_reg_input.  Response Register (Offset 010h).  If we don't have
	// a response for cmd5, we know we don't have a sdio card.
	// We'll assume the OCR field of 16 zeros means no response.
	always@(posedge clk)
	begin
		if (reset) 
			cmd5_no_resp	<= 1'b0; 		
		// If OCR is 16 zeros, we'll know that we don't have
		// any response.
		else if (rd_reg_input[15:0] == {16{1'b0}})
			cmd5_no_resp	<= 1'b1;
		// If OCR is non-zero, we know that we have a sdio card.
		else if (rd_reg_input[15:0] != {16{1'b0}})
			cmd5_no_resp	<= 1'b0;
		else 
			cmd5_no_resp	<= 1'b0;
	end		

	// If we don't have any response for cmd5, set the sdio flag to 0.
//	always@(posedge clk)
//	begin
//		if (reset) begin
//			sdio_flg	<= 1'b0; 		
//		end	
//		else if (cmd5_no_resp == 1'b1) begin
//			sdio_flg	<= 1'b0;
//		end
//		else if (cmd5_no_resp == 1'b0) begin
//			sdio_flg	<= 1'b1;
//		end
//		else begin
//			sdio_flg	<= 1'b0;
//		end
//	end
	
	// Check app_cmd bit for cmd55.
	// Only valid when we are looking at app_cmd, other
	// times, rd_reg_input may hold other registers information.
	always@(posedge clk)
	begin
		if (reset) 
			app_cmd	<= 1'b0;
		else if (rd_reg_input[5]) 		// app_cmd enabled
			app_cmd	<= 1'b1;
		//else if (!rd_reg_input[5]) 	// app_cmd not enabled
			//app_cmd	<= 1'b0;
		else 
			app_cmd	<= 1'b0;
	end
	
	// Check OCR for acmd41, becareful, other registers are written to 
	// rd_reg_input.  Response Register (Offset 010h).  If we don't have
	// a response for ocr, we know we don't have a sd card.
	// We'll assume the OCR field of [23:8] = zeros means no response.
	always@(posedge clk)
	begin
		if (reset) 
			ocr_ok			<= 1'b0; 		
			//vdd_volt_wind	<= {16{1'b0}};
		// If OCR is not 16 zeros, we'll know that we have
		// a response, ie, a sd card.
		else if (rd_reg_input[23:8] != {16{1'b0}}) 
			ocr_ok			<= 1'b1;
			// We need to get this so we can set it
			// in the acmd41 initialization command.
			//vdd_volt_wind	<= rd_reg_input[23:8];
		// If OCR has 16 zeros, we know that we do not have a sd card.
		else if (rd_reg_input[23:8] == {16{1'b0}}) 
			ocr_ok			<= 1'b0;
			//vdd_volt_wind	<= {16{1'b0}};
		else 
			ocr_ok			<= 1'b0;
			//vdd_volt_wind	<= {16{1'b0}};
	end	
	
	// Check Response Register (Offset 010h).
	// The initialization response is okay if the OCR field of [23:8] is not empty.  
	// See acmd41 response on page 23 of the physical layer simplified version 
	// 3.01. 
	always@(posedge clk)
	begin
		if (reset) 
			init_resp_ok	<= 1'b0; 		
		else if (rd_reg_input[23:8] != {16{1'b0}})
			init_resp_ok	<= 1'b1;
		// If OCR has 16 zeros, we know that we do not have a sd card.
		else if (rd_reg_input[23:8] == {16{1'b0}})
			init_resp_ok	<= 1'b0;
		else
			init_resp_ok	<= 1'b0;
	end
	
	// Check busy bit.
	// Only valid when we are looking at card_busy, other
	// times, rd_reg_input may hold other registers information.
	always@(posedge clk)
	begin
		if (reset) 
			card_busy	<= 1'b1; 	
		else if (rd_reg_input[31])	// card not busy if 1
			card_busy	<= 1'b0;
		else if (!rd_reg_input[31])// card busy if 0
			card_busy	<= 1'b1;
		else 
			card_busy	<= 1'b1;
	end									
	
	// Latch the card busy bit.
	//always@(posedge clk)
//	begin
//		if (reset) 
//			crd_bsy_ltch	<= 1'b1; 	
//		else if (card_busy)	// card busy
//			crd_bsy_ltch	<= 1'b1;
//		else if (!card_busy)	// card not busy
//			crd_bsy_ltch	<= 1'b0;
//		else 
//			crd_bsy_ltch	<= crd_bsy_ltch;
//	end
	
	// Check for card ccs.
	// Only valid when we are looking at card_ccs, other
	// times, rd_reg_input may hold other registers information.
	always@(posedge clk)
	begin
		if (reset)
			card_ccs	<= 1'b0; 		
		// Don't really need to check here since at this stage
		// we are finished with initializing, ie, the card is not
		// busy any more.
		else if (rd_reg_input[31])  // card not busy if 1
			card_ccs	<= rd_reg_input[30];
		else 
			card_ccs	<= 1'b0;
	end
	
	// Only valid when we are looking at cid, other
	// times, rd_reg_input may hold other registers information.
	always@(posedge clk)
	begin
		if (reset) 
			cid	<= {128{1'b0}}; 		
		else if (state == state_get_rca)			
			cid	<= rd_reg_input;
		else
			cid	<= cid;
	end			  	 
	
	// Capture RCA.
	always@(posedge clk)
	begin
		if (reset)
			rca	<= {16{1'b0}};
		else if ((rd_reg_input[31:16] != 16'h0000) 
					&& (state == state_chk_rca_resp_wt))
			rca	<= rd_reg_input[31:16];
		else 	
			rca	<= rca;
	end
	
	// Check for RCA.
	always@(posedge clk)
	begin
		if (reset) begin
			rca_valid			<= 1'b0;
			not_int_strb_reg	<= 1'b1;
		end
		// If RCA is not zero, we have a valid RCA and the card
		// is in stand by state, which means it is ready for 
		// communication.
		else if ((rd_reg_input[31:16] != 16'h0000) 
					&& (state == state_chk_rca_resp_wt)) begin 
			rca_valid			<= 1'b1;
			not_int_strb_reg	<= 1'b0;
		end
		else begin	
			rca_valid			<= 1'b0;
			// If RCA is zero, the card is not initialized.
			not_int_strb_reg	<= 1'b1;
		end
	end
	
endmodule
