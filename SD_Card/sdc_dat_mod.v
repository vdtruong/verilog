`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////
// Company: 			Fresenius
// Engineer: 			VDT
// 
// Create Date:    	11:52:31 08/13/2012 	 
// Update Date:    				03/21/2014 
// Design Name: 
// Module Name:    	sdc_dat_mod 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 		This module is responsibled for forming the datx packets
//							and sends them out.  It also determines if the sd card  
//							is busy by analyzing all data lines.  If D0 is pulled
//							low while the other data lines are high, it means we
//							have a busy signal.
//							Later on we will incorporate the data read from the sd
//							card.  
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
///////////////////////////////////////////////////////////////////////////////
module sdc_dat_mod(
	input					sd_clk,
   input 				reset,
	input					new_dat_set_strb, // new data coming in (tf_data)
	// Data to be transferred to sd card.  We will transfer 64 bits at a time
	// until we have sent 512 bytes and the CRC.
	input 	[63:0]	tf_data, 
	output	[15:0]	dat_crc16_out,
	output				wr_busy, // indicates that the sd card is busy
   input					D0_in, 	// only D0 has a busy signal		 
   output				D0_out, 		
	input					D1_in,											 
	output				D1_out,
	input					D2_in, 
	output				D2_out,
	input					D3_in, 
	output				D3_out, 
	output				new_rd0_pkt_strb, // new rd pkt from line dat0 
	// read packet from sd card, single line (dat0)
	// for sdhc, we will read 512 bytes at a time.
	// One block is 512 bytes.
   output 	[4113:0] rd0_pkt				// read packet from sd card, single line (dat0)
	);
	
	// Registers 
	// datax is actual data 
	reg	[1023:0]	dat0; // data for D0
	reg	[1023:0]	dat1; // data for D1
	reg	[1023:0]	dat2; // data for D2
	reg	[1023:0]	dat3; // data for D3
	// datax_pkt includes start bit, datx, crc16 and stop bit
	reg 	[35:0] 	dat0_pkt; // data = 18 bits, crc =16, start = 1, stop =1
	reg 	[35:0] 	dat1_pkt;
	reg 	[35:0] 	dat2_pkt;
	reg 	[35:0] 	dat3_pkt;
	// These registers contain the start bit and the data for the new data 
	// lines.  Right now only use these registers for crc16 calc. for new data.
	reg 	[18:0]	pre_new_dat0;
	reg 	[18:0]	pre_new_dat1;
	reg 	[18:0]	pre_new_dat2;
	reg 	[18:0]	pre_new_dat3;
	reg				shift_pre_new_dat;
	reg				shift_new_resp;	
	reg 				oe_sig;	
	reg				new_dat_strb;
	reg 				new_resp_packet_strb_z1;
	reg				new_resp_packet_strb_z2;
	reg				new_resp_packet_strb_z3;
	reg				mon_wr_busy_flg; // monitor write busy
	reg				wr_busy_flg;
	reg 	[47:0] 	resp_packet_reg;
	reg				D0_reg;
	reg				D1_reg;
	reg				D2_reg;
	reg				D3_reg;
	reg				D0_reg_z1;
																															
	// Wires
	wire	[11:0]	dat0_crc16_cnt;
	wire	[15:0]	dat0_crc16;
	wire	[15:0]	dat1_crc16;
	wire	[15:0]	dat2_crc16;
	wire	[15:0]	dat3_crc16;
	wire 				new_resp_packet_strb;
	wire				new_r2_packet_strb;
	//wire 	[47:0] 	resp_packet;
	//wire 	[135:0] 	resp2_packet;
	wire	[6:0]		resp_crc7;
	wire	[6:0]		resp2_crc7;
	wire				fin_19Clks_dat_strb;
	wire				finish_40Clks_resp_strb;
	wire				finish_18Clks_resp_strb;
	wire				fin_36Clks_dat_strb;
	wire				resp_timeout_strb;
	//wire 	[4095:0]	rd0_pkt;
	wire 	[1041:0]	rd1_pkt;
	wire 	[1041:0]	rd2_pkt;
	wire 	[1041:0]	rd3_pkt;
	
	// Initialize sequential logic (regs)
	initial			
	begin
		dat0		 					<= {1024{1'b0}};
		dat1		 					<= {1024{1'b0}};
		dat2		 					<= {1024{1'b0}};
		dat3		 					<= {1024{1'b0}};
		dat0_pkt 					<= {36{1'b0}};
		dat1_pkt 					<= {36{1'b0}};
		dat2_pkt 					<= {36{1'b0}};
		dat3_pkt 					<= {36{1'b0}};
		pre_new_dat0 				<= {19{1'b0}};
		pre_new_dat1 				<= {19{1'b0}};
		pre_new_dat2 				<= {19{1'b0}};
		pre_new_dat3 				<= {19{1'b0}};
		shift_pre_new_dat			<=	1'b0;
		shift_new_resp				<=	1'b0;
		oe_sig						<=	1'b0;		
		new_dat_strb				<=	1'b0;
		new_resp_packet_strb_z1	<= 1'b0;
		new_resp_packet_strb_z2	<= 1'b0;
		new_resp_packet_strb_z3	<= 1'b0;
		mon_wr_busy_flg			<= 1'b0;
		wr_busy_flg	 				<= 1'b0;
		resp_packet_reg 			<= {{47{1'b0}}, 1'b1};
		//new_state_strb				<= 1'b0;
		//new_state_strb_z1			<= 1'b0;
		//new_state_strb_z2			<= 1'b0;
		//r2_resp_enb					<= 1'b1;
		//r2_resp_packet_reg		<= {{2{1'b0}}, {6{1'b1}}, {17{1'b0}}, 1'b1};
		//r2_crc7_good				<= 1'b0;
		D0_reg						<= 1'b0;
		D1_reg						<= 1'b0;
		D2_reg						<= 1'b0;
		D3_reg						<= 1'b0;
		D0_reg_z1					<= 1'b0;
	end  
	
	assign new_response_packet_strb 		= new_resp_packet_strb;
	assign new_response_2_packet_strb 	= new_r2_packet_strb;
	//assign response_packet					= resp_packet;
	//assign r2_packet							= resp2_packet;
	assign dat_crc16_out 					= dat0_crc16;
//	assign resp_crc7_out 					= resp_crc7;
//	assign resp2_crc7_out 					= resp2_crc7;
	assign wr_busy								= wr_busy_flg;
	//assign r2_crc7_good_out					= r2_crc7_good;
	//assign D0_reg								= D0;
	//assign D1_reg								= D1;
	//assign D2_reg								= D2;
	//assign D3_reg								= D3;
	
	/////////////////////////////////////////////////////
	// Set up delays.
	always@(posedge sd_clk)
	begin
		if (reset) begin
			new_resp_packet_strb_z1	<= 1'b0;
			new_resp_packet_strb_z2	<= 1'b0;
			new_resp_packet_strb_z3	<= 1'b0;
			D0_reg_z1					<= 1'b0;
			//valid_R7_z1					<= 1'b0;
			//new_state_strb_z1			<= 1'b0;
			//new_state_strb_z2			<= 1'b0;
			//resp_crc7_good_z1			<= 1'b0;
		end
		else begin
			new_resp_packet_strb_z1	<= new_resp_packet_strb;
			new_resp_packet_strb_z2	<= new_resp_packet_strb_z1;
			new_resp_packet_strb_z3	<= new_resp_packet_strb_z2;
			D0_reg_z1					<= D0_reg;
			//valid_R7_z1					<= valid_R7;
			//new_state_strb_z1			<= new_state_strb;
			//new_state_strb_z2			<= new_state_strb_z1;
			//resp_crc7_good_z1			<= resp_crc7_good;
		end
	end

	// Sending data begins. ////////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
	// Rearrange the incoming transfer data into the four different data lines.
	// We are using 8-bit Width Data and Wide Bus Data Line. 8-bit Width means 8
	// bits of data.  Wide Bus means four data lines.
	// Each data line has 18 bits of data.  Refer to Figure 3-7 on page 9 of the
	// Physical Layer Simplified Specification Version 2.00.
	//always@(posedge sd_clk)
//	begin
//		if (reset) begin
//			dat0 	<= {18{1'b0}};
//			dat1 	<= {18{1'b0}};
//			dat2	<= {18{1'b0}};
//			dat3	<= {18{1'b0}};
//		end
//		else if (new_dat_set_strb) begin
//			// DAT3 data line
//			dat3 	<= {	tf_data[7],tf_data[3],
//							tf_data[15],tf_data[11],
//						 	tf_data[23],tf_data[19],
//							tf_data[31],tf_data[27],
//							tf_data[39],tf_data[35],
//							tf_data[47],tf_data[43],
//						 	tf_data[55],tf_data[51],
//							tf_data[63],tf_data[59],
//						 	tf_data[71],tf_data[67],
//							tf_data[79],tf_data[75],
//						 	tf_data[87],tf_data[83],
//							tf_data[95],tf_data[91],
//							tf_data[103],tf_data[99],
//							tf_data[111],tf_data[107],
//						 	tf_data[119],tf_data[115],
//							tf_data[127],tf_data[123],
//						 	tf_data[135],tf_data[131],
//							tf_data[143],tf_data[139],
//						 	tf_data[151],tf_data[147],
//							tf_data[159],tf_data[155],
//							tf_data[167],tf_data[163],
//							tf_data[175],tf_data[171],
//						 	tf_data[183],tf_data[179],
//							tf_data[191],tf_data[187],
//						 	tf_data[199],tf_data[195],
//							tf_data[207],tf_data[203],
//						 	tf_data[215],tf_data[211],
//							tf_data[223],tf_data[219],
//							tf_data[231],tf_data[227],
//							tf_data[239],tf_data[235],
//						 	tf_data[247],tf_data[243],
//							tf_data[255],tf_data[251],
//						 	tf_data[263],tf_data[259],
//							tf_data[271],tf_data[267],
//						 	tf_data[279],tf_data[275],
//							tf_data[287],tf_data[283],
//							tf_data[295],tf_data[291],
//							tf_data[303],tf_data[299],
//						 	tf_data[311],tf_data[307],
//							tf_data[319],tf_data[315],
//						 	tf_data[327],tf_data[323],
//							tf_data[335],tf_data[331],
//						 	tf_data[343],tf_data[339],
//							tf_data[351],tf_data[347],
//							tf_data[359],tf_data[355],
//							tf_data[367],tf_data[363],
//						 	tf_data[375],tf_data[371],
//							tf_data[383],tf_data[379],
//						 	tf_data[391],tf_data[387],
//							tf_data[399],tf_data[395],
//						 	tf_data[407],tf_data[403],
//							tf_data[415],tf_data[411],
//							tf_data[423],tf_data[419],
//							tf_data[431],tf_data[427],
//						 	tf_data[439],tf_data[435],
//							tf_data[447],tf_data[443],
//						 	tf_data[455],tf_data[451],
//							tf_data[463],tf_data[459],
//						 	tf_data[471],tf_data[467],
//							tf_data[479],tf_data[475],
//							tf_data[487],tf_data[483],
//							tf_data[495],tf_data[491],
//						 	tf_data[503],tf_data[499],
//							tf_data[511],tf_data[507],
//						 	tf_data[519],tf_data[515],
//							tf_data[527],tf_data[523],
//							tf_data[535],tf_data[531],
//							tf_data[543],tf_data[539],
//						 	tf_data[551],tf_data[547],
//							tf_data[559],tf_data[555],
//						 	tf_data[567],tf_data[563],
//							tf_data[575],tf_data[571],
//						 	tf_data[583],tf_data[579],
//							tf_data[591],tf_data[587],
//							tf_data[599],tf_data[595],
//							tf_data[607],tf_data[603],
//						 	tf_data[615],tf_data[611],
//							tf_data[623],tf_data[619],
//						 	tf_data[631],tf_data[627],
//						 	tf_data[639],tf_data[635],
//							tf_data[647],tf_data[643],
//							tf_data[655],tf_data[651],
//							tf_data[663],tf_data[659],
//						 	tf_data[671],tf_data[667],
//							tf_data[679],tf_data[675],
//						 	tf_data[687],tf_data[683],
//							tf_data[695],tf_data[691],
//						 	tf_data[703],tf_data[699],
//							tf_data[711],tf_data[707],
//							tf_data[719],tf_data[715],
//							tf_data[727],tf_data[723],
//						 	tf_data[735],tf_data[731],
//							tf_data[743],tf_data[739],
//						 	tf_data[751],tf_data[747],
//							tf_data[759],tf_data[755],
//							tf_data[767],tf_data[763],
//							tf_data[775],tf_data[771],
//						 	tf_data[783],tf_data[779],
//							tf_data[791],tf_data[787],
//						 	tf_data[799],tf_data[795],
//							tf_data[807],tf_data[803],
//						 	tf_data[815],tf_data[811],
//							tf_data[823],tf_data[819],
//							tf_data[831],tf_data[827],
//							tf_data[839],tf_data[835],
//						 	tf_data[847],tf_data[843],
//							tf_data[855],tf_data[851],
//						 	tf_data[863],tf_data[859]};
//			// DAT2 data line
//			dat2 	<= {	tf_data[6],tf_data[2],
//							tf_data[14],tf_data[10],
//						 	tf_data[22],tf_data[18],
//							tf_data[30],tf_data[26],
//						 	tf_data[38],tf_data[34],
//							tf_data[46],tf_data[42],
//						 	tf_data[54],tf_data[50],
//							tf_data[62],tf_data[58],
//						 	tf_data[70],tf_data[66]};
//			// DAT1 data line
//			dat1 	<= {	tf_data[5],tf_data[1],
//							tf_data[13],tf_data[9],
//						 	tf_data[21],tf_data[17],
//							tf_data[29],tf_data[25],
//						 	tf_data[37],tf_data[33],
//							tf_data[45],tf_data[41],
//						 	tf_data[53],tf_data[49],
//							tf_data[61],tf_data[57],
//						 	tf_data[69],tf_data[65]};
//			// DAT0 data line
//			dat0 	<= {	tf_data[4],tf_data[0],
//							tf_data[12],tf_data[8],
//						 	tf_data[20],tf_data[16],
//							tf_data[28],tf_data[24],
//						 	tf_data[36],tf_data[32],
//							tf_data[44],tf_data[40],
//						 	tf_data[52],tf_data[48],
//							tf_data[60],tf_data[56],
//						 	tf_data[68],tf_data[64]};
//		end
//		else begin
//			dat0 	<= dat0;
//			dat1 	<= dat1;
//			dat2 	<= dat2;
//			dat3 	<= dat3;
//		end
//	end
	
	// Create a flag to allow shifting of the pre_new_dat for crc16 
	// calculation.  
	always@(posedge sd_clk)
	begin
		if (reset) 
			shift_pre_new_dat <= 1'b0;
		else if (new_dat_set_strb) 
			shift_pre_new_dat <= 1'b1;	
		// Also need to turn this off so we don't
		// have to shift it any more.
		else if (fin_19Clks_dat_strb) 
			shift_pre_new_dat <= 1'b0;
	end
	
	//-------------------------------------------------------------------------
	// We need a generic 19 clocks counter for the datx crc16 calculator.  
	//-------------------------------------------------------------------------
	defparam gen19ClksDatCntr_u1.dw 	= 8;
	defparam gen19ClksDatCntr_u1.max	= 8'h12;	// 19 counts (0-18).
	//-------------------------------------------------------------------------
	CounterSeq gen19ClksDatCntr_u1(
		.clk(sd_clk), 	// Clock input 25 MHz 
		.reset(reset),	// GSR
		.enable(1'b1), 	
		// start to calculate the crc16
		.start_strb(new_dat_set_strb),  	 	
		.cntr(), 
		.strb(fin_19Clks_dat_strb) // should finish calculating crc16.
	);
	
	// Shifts (left) the data into the crc16 calculator
	// and determines the next pre_new_dat0.
	// The crc calculator takes in one bit at a time.
	always@(posedge sd_clk)
	begin
		if (reset) 
			pre_new_dat0	 		<= {1'b0, {4096{1'b0}}};
		else if (shift_pre_new_dat)			
			pre_new_dat0[18:1]	<= pre_new_dat0[17:0];
		else if (new_dat_set_strb)			
			// Set the pre_new_dat0 according to dat0.
			pre_new_dat0			<= {1'b0, dat0}; // start bit and data0
		else 
			pre_new_dat0 			<= pre_new_dat0;
	end
	
	// Shifts (left) the data into the crc16 calculator
	// and determines the next pre_new_dat1.
	always@(posedge sd_clk)
	begin
		if (reset) 
			pre_new_dat1	 		<= {1'b0, {4096{1'b0}}};
		else if (shift_pre_new_dat) 			
			pre_new_dat1[18:1]	<= pre_new_dat1[17:0];
		else if (new_dat_set_strb)			
			// Set the pre_new_dat1 according to dat1.
			pre_new_dat1			<= {1'b0, dat1};
		else
			pre_new_dat1 			<= pre_new_dat1;
	end
	
	// Shifts (left) the data into the crc16 calculator
	// and determines the next pre_new_dat2.
	always@(posedge sd_clk)
	begin
		if (reset) 
			pre_new_dat2	 		<= {1'b0, {4096{1'b0}}};
		else if (shift_pre_new_dat)			
			pre_new_dat2[18:1]	<= pre_new_dat2[17:0];
		else if (new_dat_set_strb)			
			// Set the pre_new_dat2 according to dat2.
			pre_new_dat2			<= {1'b0, dat2};
		else 
			pre_new_dat2 			<= pre_new_dat2;
	end
	
	// Shifts (left) the data into the crc16 calculator
	// and determines the next pre_new_dat3.
	always@(posedge sd_clk)
	begin
		if (reset) 
			pre_new_dat3	 		<= {1'b0, {4096{1'b0}}};
		else if (shift_pre_new_dat) 			
			pre_new_dat3[18:1]	<= pre_new_dat3[17:0];
		else if (new_dat_set_strb)			
			// Set the pre_new_dat3 according to dat3.
			pre_new_dat3			<= {1'b0, dat3};
		else
			pre_new_dat3 			<= pre_new_dat3;
	end
	
	// Calculates the crc16 of the pre_new_dat0.
	// When we shift the pre new data, we also
	// need to restart the crc calculator.
	sd_crc_16 genDatCrc16_u2(
		.BITVAL(pre_new_dat0[18]),		// Next input bit
    	.Enable(shift_pre_new_dat),      
		.CLK(sd_clk),    					// Current bit valid (Clock)
      .RST(new_dat_set_strb),
   	.CRC(dat0_crc16)
	);
	
	// Calculates the crc16 of the pre_new_dat1.
	// When we shift the pre new data, we also
	// need to restart the crc calculator.
	sd_crc_16 genDatCrc16_u3(
		.BITVAL(pre_new_dat1[18]),		// Next input bit
    	.Enable(shift_pre_new_dat),      
		.CLK(sd_clk),    					// Current bit valid (Clock)
      .RST(new_dat_set_strb),
   	.CRC(dat1_crc16)
	);
	
	// Calculates the crc16 of the pre_new_dat2.
	// When we shift the pre new data, we also
	// need to restart the crc calculator.
	sd_crc_16 genDatCrc16_u4(
		.BITVAL(pre_new_dat2[18]),		// Next input bit
    	.Enable(shift_pre_new_dat),      
		.CLK(sd_clk),    					// Current bit valid (Clock)
      .RST(new_dat_set_strb),
   	.CRC(dat2_crc16)
	);
	
	// Calculates the crc16 of the pre_new_dat3.
	// When we shift the pre new data, we also
	// need to restart the crc calculator.
	sd_crc_16 genDatCrc16_u5(
		.BITVAL(pre_new_dat3[18]),		// Next input bit
    	.Enable(shift_pre_new_dat),      
		.CLK(sd_clk),    					// Current bit valid (Clock)
      .RST(new_dat_set_strb),
   	.CRC(dat3_crc16)
	);
	
	// We need to build the dat0_packet.
	always@(posedge sd_clk)
	begin
		if (reset) 
			dat0_pkt	<= {1'b0, {4096{1'b0}}, {16{1'b0}}, 1'b1};
		else if (fin_19Clks_dat_strb)  // wait to get dat0_crc16
			dat0_pkt	<= {1'b0, dat0, dat0_crc16, 1'b1};
	end
	
	// We need to build the dat1_packet.
	always@(posedge sd_clk)
	begin
		if (reset) 
			dat1_pkt	<= {1'b0, {4096{1'b0}}, {16{1'b0}}, 1'b1};
		else if (fin_19Clks_dat_strb)  // wait to get dat1_crc16
			dat1_pkt	<= {1'b0, dat1, dat1_crc16, 1'b1};
	end
	
	// We need to build the dat2_packet.
	always@(posedge sd_clk)
	begin
		if (reset)
			dat2_pkt	<= {1'b0, {4096{1'b0}}, {16{1'b0}}, 1'b1};
		else if (fin_19Clks_dat_strb)  // wait to get dat2_crc16
			dat2_pkt	<= {1'b0, dat2, dat2_crc16, 1'b1};
	end
	
	// We need to build the dat3_packet.
	always@(posedge sd_clk)
	begin
		if (reset) 
			dat3_pkt	<= {1'b0, {4096{1'b0}}, {16{1'b0}}, 1'b1};
		else if (fin_19Clks_dat_strb)  // wait to get dat3_crc16
			dat3_pkt	<= {1'b0, dat3, dat3_crc16, 1'b1};
	end
	
	///////////////////////////////////////////////////////////////////////////
	//-------------------------------------------------------------------------
	// This is the data transfer counter, 1042 clocks.
	// Everytime we start to send data, we need to start the oe_sig and
	// this generic counter.
	//-------------------------------------------------------------------------
	defparam datTranCntr_u6.dw 	= 12;
	defparam datTranCntr_u6.max	= 12'h413;	//  1043 counts, starts at zero.
	//-------------------------------------------------------------------------
	CounterSeq datTranCntr_u6 (
		.clk(sd_clk), 						// Clock input 25 MHz 
		.reset(reset),						// GSR
		.enable(1'b1), 	
		// start to send data
		.start_strb(fin_19Clks_dat_strb),  	 	
		.cntr(), 
		.strb(fin_36Clks_dat_strb) 	// should finish sending a command.      
	);
	
	// Need to create a signal for the oe_reg.
	// Don't want to strobe it, need to carry it out
	// as long as we send the command.
	always @(posedge sd_clk)
		if(reset) begin
         oe_sig 			<= 1'b0;	// output enable signal
			new_dat_strb	<=	1'b0;
		end
		else if (fin_19Clks_dat_strb) begin
			// Send out the data after we have calculated the data crc16.
			// Sends out data on the datx line when oe_sig is one.
			// oe_sig is a latch, new_dat_strb is a strobe.
         oe_sig 			<= 1'b1;
			new_dat_strb	<=	1'b1;
      end 
		else if (fin_36Clks_dat_strb) 
			/* We also need to turn it off oe_sig
			   when we are done with datx. */
			oe_sig 			<= 1'b0;
		else 
			// create a strobe by pulling it to zero after one clock
			new_dat_strb	<=	1'b0;
		
	dat_serial_mod dat_serial_mod_u7(
		.sd_clk(sd_clk),
		.reset(reset),
		//.oe_sig(oe_sig),
		.new_dat_strb(new_dat_strb),
		.dat_pkt(tf_data),
		.dat_in(D0_in),			  
		.dat_out(D0_out),
		.new_rd_pkt_strb(new_rd0_pkt_strb), 
		.rd_pkt(rd0_pkt)
   );
	
	dat_serial_mod dat_serial_mod_u8(
		.sd_clk(sd_clk),
		.reset(reset),
		//.oe_sig(oe_sig),
		.new_dat_strb(new_dat_strb),
		.dat_pkt(dat1_pkt),
		.dat_in(D1_in),			  
		.dat_out(D1_out),
		.new_rd_pkt_strb(new_rd1_pkt_strb), 
		.rd_pkt(rd1_pkt)
   );
	
	dat_serial_mod dat_serial_mod_u9(
		.sd_clk(sd_clk),
		.reset(reset),
		//.oe_sig(oe_sig),
		.new_dat_strb(new_dat_strb),
		.dat_pkt(dat2_pkt),
		.dat_in(D2_in),			  
		.dat_out(D2_out),
		.new_rd_pkt_strb(new_rd2_pkt_strb), 
		.rd_pkt(rd2_pkt)
   );
	
	dat_serial_mod dat_serial_mod_u10(
		.sd_clk(sd_clk),
		.reset(reset),
		//.oe_sig(oe_sig),
		.new_dat_strb(new_dat_strb),
		.dat_pkt(dat3_pkt),
		.dat_in(D3_in),			  
		.dat_out(D3_out),
		.new_rd_pkt_strb(new_rd3_pkt_strb), 
		.rd_pkt(rd3_pkt)
   );
	
	// Get the registers for D0-D3.
	// We need to monitor D0 to see if it is busy.
	always@(posedge sd_clk)
	begin
		if (reset) begin
			D0_reg	<= 1'b0;
			D1_reg	<= 1'b0;
			D2_reg	<= 1'b0;
			D3_reg	<= 1'b0;
		end
		else begin
			D0_reg	<= D0_in;
			D1_reg	<= D1_in;
			D2_reg	<= D2_in;
			D3_reg	<= D3_in;
		end
	end
	
	// After we finished writing out the data,
	// We need to monitor D0 to see if the sd card is busy.
	// Here we set up the flag to begin and end monitoring
	// the DAT0 line.
	always@(posedge sd_clk)
	begin
		if (reset) 
			mon_wr_busy_flg	<= 1'b0;	
		else if (fin_36Clks_dat_strb) 
			mon_wr_busy_flg	<= 1'b1;					
		else if (mon_wr_busy_flg && !wr_busy_flg) 
			mon_wr_busy_flg	<= 1'b0;	
	end
	
	// We know DAT0 is busy if it is held low after 
	// a successful transfer of data to the sd card.
	// When the DAT0 line is released to high, the line
	// is no longer busy.
	always@(posedge sd_clk)
	begin
		if (reset)
			wr_busy_flg	<= 1'b0;									  
		else if (mon_wr_busy_flg & (!D0_reg && D0_reg_z1)) // falling edge
			wr_busy_flg	<= 1'b1;									  
		else if (mon_wr_busy_flg & (D0_reg && !D0_reg_z1)) // rising edge
			wr_busy_flg	<= 1'b0;
	end
	// Sending data ends. //////////////////////////////////////////////////////
	
	// Begin listening to data. ////////////////////////////////////////////////
	////////////////////////////////////////////////////////////////////////////
endmodule
