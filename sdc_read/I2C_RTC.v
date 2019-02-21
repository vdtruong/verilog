/*-----------------------------------------------------------------------------
  Module:     I2C_RTC
  
  Description: Implements I2C Interface for RTC ISL1208.
					Whenever we need to change the clock information (RTC section),
					we need to write to bit WRTC of the SR control byte first.
					Also, in order to read the RTC information for the first time, 
					We need to write 1 to WRTC so the chip will start to count.  If
					we don't do this, we will see only zeros.  See page 12 in the 
					WRTC section.
  
  Date:	10/18/2012
  
-----------------------------------------------------------------------------*/
module I2C_RTC
#(parameter I2C_ADDRESS  = 8'hDe,     	//  Address for slave I2C RTC
  parameter BAUD_MASK    = 16'h00C7)	//  Baud Rate Counter  250KHz bus rate
(  
  //System Inputs
  input              clk,        	//  System Clock 
  input              reset,      	//  System Reset (Syncronous)  
  input              enable,     	//  Enable this interface
  input              strb_500ms, 	//  500ms Strobe
  
  // RTC inputs
  input					wr_rtc_strb,	//  strobe to write information to the RTC
  //  32 bits -- sc(8), mn(8), hr(8), dt(8)
  input [35:0] 		wreg_RTC_01,	
  //  24 bits -- mo(8), yr(8), dw(8)
  input [23:0] 		wreg_RTC_02,	
  
  // RTC output
  output reg[31:0]   rtc_01,     	//  This includes sc, mn, hr and dt.
  output reg[23:0]   rtc_02,     	//  This includes mo, yr and dw.
  output reg         rtc_status,		//  RTC sensor status, like nack
  output reg         rtc_strb,   	//  Strobe that new rtc data is ready
  
  //I2C two wire interface. 1 = tri-state, 0 = drain at top level
  input              I2C_SCL_in, 	//  Input SCL (As Slave)
  output             I2C_SCL_out,	//  Output SCL (As Master)
  input              I2C_SDA_in,    //  Input SDA (Master Ack/Nack, Slave Recieve)
  output             I2C_SDA_out    //  Output SDA (Master/Slave Ack/Nack)
);

	reg         strb_500msZ1;
	reg         seq_enable;
	reg			serv_req_flag;
	reg			serv_enb_flg;
  
  wire        strb_rx;
  wire        tx_cmplt;
  
  wire        mstr_strb_start; 	// master strobe start
  wire        mstr_strb_stop;		// master strobe stop
  wire        strb_tx;
  reg  [7:0]  data_tx;
  reg			  rx_nack;
  wire [7:0]  data_rx;
  wire        strb_rd;
  wire        bus_master;
  wire        tx_nack;     
  
  wire        rd_rtc_sc;
  wire        rd_rtc_mn;
  wire        rd_rtc_hr;
  wire        rd_rtc_dt;
  wire        rd_rtc_mo;
  wire        rd_rtc_yr;
  wire        rd_rtc_dw;
  
  wire        next_op_strb;
  wire        seq_strb;
  wire [5:0]  seq_cntr;

	initial
	begin
		strb_500msZ1	<= 1'b0;    
		seq_enable     <= 1'b0;
		rtc_01      	<= 32'h00000000;
		rtc_02      	<= 24'h000000;
		rtc_status     <= 1'b0;
		rtc_strb       <= 1'b0;
		rx_nack			<= 1'b0;
		serv_req_flag	<= 1'b0;
		serv_enb_flg	<= 1'b0;
	end

  //-----------------------------------------------------------------------------------------
  // I2C Com Port Interfaec for the I2C bus
  defparam I2C_ComPort_i.BAUD_MASK = BAUD_MASK;
  //-----------------------------------------------------------------------------------------
  I2C_ComPort I2C_ComPort_i(  
    .clk(clk),                  //  System Clock 
    .reset(reset),              //  System Reset (Syncronous)
    .strb_start(mstr_strb_start),    //  Input Strobe to start if master
    .strb_stop(mstr_strb_stop),      //  Input Strobe to stop if master
    .strb_tx(strb_tx),          //  Input Strobe to send the byte 
    .data_tx(data_tx),          //  Input [7:0] Data byte to transmit 
	 .rx_nack(rx_nack),          //  Flag to indicate to show a nack on the next read byte
    .tx_cmplt(tx_cmplt),        //  Output Strobe that transmition is complete
    .tx_nack(tx_nack),          //  Output Flag to indicate no acknoledge from last transfer
    .bus_master(bus_master),    //  Output Flag to indicate currently bus master  
    .bus_slave(1'b0),           //  Input Flag to indicate reciever is bus_slave
    .strb_rd(strb_rd),          //  Input Strobe to recieve the next byte on the bus
    .strb_S(),                  //  Output Strobe that an S (start has been recieved)
    .strb_P(),                  //  Output Strobe that a P (stop has been recieved)
    .strb_rx(strb_rx),          //  Output Strobe that a byte has been recieved
    .data_rx(data_rx),          //  Output Data byte recieved  
    .I2C_SCL_in(I2C_SCL_in),    //  Input SCL (As Slave)
    .I2C_SCL_out(I2C_SCL_out),  //  Output SCL (As Master)
    .I2C_SDA_in(I2C_SDA_in),    //  Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_SDA_out(I2C_SDA_out)   //  Output SDA (Master/Slave Ack/Nack)
  );
  
	// If we need to write to the RTC, we will
	// need to use this sequence.  It includes
	// the write to the WRTC bit first then
	// the 7 RTC registers.
	// 00       S Start bit                  
	// 01       W 0xDe, slave identification byte with write bit.  
	// 02       W 0x07, SR -  write to the SR status register.
	// 03       W 0x10, data byte, write 1 to WRTC
	// 04       P Stop bit
	// 05       S Start bit
	// 06       W 0xDe, slave identification byte with write bit.
	// 07       W 0x00, SC -  write to the seconds register.
	// 08       W 0xXX, data byte
	// 09       P Stop bit
	// 0a       S Start bit
	// 0b       W 0xDe, slave identification byte with write bit.
	// 0c       W 0x01, MN -  write to the minute register.
	// 0d       W 0xXX, data byte
	// 0e       P Stop bit
	// 0f			S Start bit
	// 10       W 0xDe, slave identification byte with write bit.
	// 11       W 0x02, HR -  write to the hour register.
	// 12       W 0xXX, data byte
	// 13       P Stop bit
	// 14			S Start bit
	// 15       W 0xDe, slave identification byte with write bit.
	// 16       W 0x03, DT -  write to the date register.
	// 17       W 0xXX, data byte
	// 18       P Stop bit
	// 19			S Start bit
	// 1a       W 0xDe, slave identification byte with write bit.
	// 1b       W 0x04, MO -  write to the month register.
	// 1c       W 0xXX, data byte
	// 1d       P Stop bit
	// 1e			S Start bit
	// 1f       W 0xDe, slave identification byte with write bit.
	// 20      	W 0x05, YR -  write to the year register.
	// 21       W 0xXX, data byte
	// 22       P Stop bit
	// 23			S Start bit
	// 24       W 0xDe, slave identification byte with write bit.
	// 25      	W 0x06, DW -  write to the day of week register.
	// 26       W 0xXX, data byte
	// 27       P Stop bit
	
	// Use this sequence if we are only doing the readings.
	// Sequencer For RTC read of 7 registers.
	// Trigger from 500ms
	// Read RTC
	//  
	// 00       S Start bit                  
	// 01       W 0xDe, slave identification byte with write bit.  
	// 02       W 0x00, SC - seconds byte, write the starting address.
	// 03       S Start bit
	// 04       R 0xDF, slave identification byte with read bit.
	// 05       rd --> SC - seconds byte
	// 06       rd --> MN - minutes byte
	// 07       rd --> HR - hours byte
	// 08       rd --> DT - date byte
	// 09       rd --> MO - month byte
	// 10       rd --> YR - year byte
	// 11       rd --> DW - day of week byte
	//	12			Remember to send a nack after finish reading
	// 13       P Stop bit

	//Enable Sequence
	always@(posedge clk)
	begin
		if (reset | seq_strb)
			seq_enable <= 1'b0; 		  
		else if (strb_500ms)
			seq_enable <= 1'b1; 		      
	end	

	//---------------------------------------------------------------
	// Sequence Counter for RTC sequence of operations
		defparam RTCSeq_i.dw		= 6;
		defparam RTCSeq_i.max 	= 6'h28;	// h28, 40d       
	//---------------------------------------------------------------
	CounterSeq RTCSeq_i
	(
		.clk(clk),                 // Clock input 50 MHz 
		.reset(reset),         		// Reset
		.enable(next_op_strb),   	// Enable Operation
		.start_strb(strb_500ms), 	// Start Strobe every 500 ms
		.cntr(seq_cntr),         	// Sequence counter value
		.strb(seq_strb)          	// Strobe when sequence is complete
	); 

	// Delay 500ms strobe by 1 clock
	always@(posedge clk)
	begin
		if (reset)
			strb_500msZ1 <= 1'b0; 		  
		else
			strb_500msZ1 <= strb_500ms;
	end	

	// Set the rx_nack one byte before the last read.
	always@(posedge clk)
	begin
		if (reset)
			rx_nack <= 1'b0; 		  
		else if (seq_cntr == 6'h0b && !serv_enb_flg)
			rx_nack <= 1'b1;
		else 
			rx_nack <= 1'b0;
	end

	// Set the serv_req_flag.
	always@(posedge clk)
	begin
		if (reset)
			serv_req_flag <= 1'b0; 		  
		else if (wr_rtc_strb)
			serv_req_flag <= 1'b1;
		else if (seq_strb && serv_req_flag && serv_enb_flg)
			serv_req_flag <= 1'b0;
	end
	
	// Set the serv_enb_flg.
	always@(posedge clk)
	begin
		if (reset)
			serv_enb_flg <= 1'b0; 		  
		else if (strb_500ms && serv_req_flag)
			serv_enb_flg <= 1'b1;
		else if (seq_strb && serv_req_flag && serv_enb_flg)
			serv_enb_flg <= 1'b0;
	end

	// Strobe to move to next operation in sequence --outputs
	// Do we need to put serv_enb_flg here?
	assign next_op_strb 		= 	(strb_500msZ1 | tx_cmplt | strb_rx) 
										& seq_enable;   

	// Input Strobe to start if master
	// We do a start bit at 0, 5, a, f, 14, 19, 1e and 23 for write only.
	// We do a start bit at 0 and 3 for reading only.
	assign mstr_strb_start  = 	serv_enb_flg == 1 ? next_op_strb &  
										((seq_cntr == 6'h00) | (seq_cntr == 6'h05) | 
										(seq_cntr == 6'h0a) | (seq_cntr == 6'h0f) | 
										(seq_cntr == 6'h14) | (seq_cntr == 6'h19) |
										(seq_cntr == 6'h1e) | (seq_cntr == 6'h23)) 
										: next_op_strb & ((seq_cntr == 6'h00) |	          
										(seq_cntr == 6'h03));
  
	// Input Strobe to stop if master
	assign mstr_strb_stop   = 	serv_enb_flg == 1 ? next_op_strb & 
										((seq_cntr == 6'h04) | (seq_cntr == 6'h09) | 
										(seq_cntr == 6'h0e) | (seq_cntr == 6'h13) | 
										(seq_cntr == 6'h18) | (seq_cntr == 6'h1d) | 
										(seq_cntr == 6'h22) | (seq_cntr == 6'h27))
										: next_op_strb & seq_cntr == 6'h0c;
	
	// Output Strobe that a byte has been recieved (strb_rx)
	// Not going to insert the serv_enb_flg here because
	// the writting is going to be so quick that the next
	// time we read, we should be able to read good values.
	// May not be a good assumption.
	// Read seconds
	assign rd_rtc_sc 	= 	strb_rx & (seq_cntr == 6'h06);
  
	// Read minutes
	assign rd_rtc_mn 	= 	strb_rx & (seq_cntr == 6'h07);
  
	// Read hours
	assign rd_rtc_hr 	= 	strb_rx & (seq_cntr == 6'h08);
  
	// Read date
	assign rd_rtc_dt 	= 	strb_rx & (seq_cntr == 6'h09);
	
	// Read month
	assign rd_rtc_mo 	= 	strb_rx & (seq_cntr == 6'h0a);
  
	// Read year
	assign rd_rtc_yr 	= 	strb_rx & (seq_cntr == 6'h0b);
  
	// Read day of week
	assign rd_rtc_dw 	= 	strb_rx & (seq_cntr == 6'h0c);
	
	// Input Strobe to recieve the next byte on the bus
	assign strb_rd 	=	serv_enb_flg == 1 ? next_op_strb & 
								seq_cntr == 6'h28: // dummy read
								next_op_strb & (seq_cntr == 6'h05 | 
								seq_cntr == 6'h06 | seq_cntr == 6'h07 | 
								seq_cntr == 6'h08 | seq_cntr == 6'h09 | 
								seq_cntr == 6'h0a | seq_cntr == 6'h0b);
  
	// Input Strobe to send the byte, strobe when writting to the rtc.
	assign strb_tx 	= next_op_strb & ~mstr_strb_start & ~mstr_strb_stop & 
								~strb_rd;
  
	// Sequence for writting or reading data to/from the RTC registers.
	// If serv_enb_flg is true, we'll do the writting, if not we will
	// only read.  But we will still go through the entire sequence
	// either way.
	always@(seq_cntr, serv_enb_flg, wreg_RTC_01, wreg_RTC_02)
	begin    
		case (seq_cntr)
			6'h00 : data_tx <= 8'h00;                   															// 00 S Start bit                  
			6'h01 : data_tx <= {I2C_ADDRESS[7:1],1'b0}; 															// 01 W 0xDE
			6'h02 : data_tx <= serv_enb_flg == 1 ? 8'h07 							: 8'h00;  				// 02 W 0x07  		or W 0x00 for starting read address 
			6'h03 : data_tx <= serv_enb_flg == 1 ? {{3{1'b0}},1'b1,{4{1'b0}}} : 8'h00;					// 03 W 0x10 		or start bit S
			6'h04 : data_tx <= serv_enb_flg == 1 ? 8'h00 : {I2C_ADDRESS[7:1],1'b1}; 					// 04 P Stop bit 	or R 0xDF
			6'h05 : data_tx <= 8'h00;                   															// 05 S Start bit or rd --> SC
			6'h06 : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 06 W 0xDe 		or rd --> MN
			6'h07 : data_tx <= 8'h00;                   															// 07 W 0x00      or rd --> HR
			6'h08 : data_tx <= serv_enb_flg == 1 ? wreg_RTC_01[31:24] 		: 8'h00; 	 				// 08 W 0xXX		or rd --> DT
			6'h09 : data_tx <= 8'h00;                   															// 09 P Stop bit  or rd --> MO
			6'h0a : data_tx <= 8'h00;                   															// 10 Start bit	or rd --> YR
			6'h0b : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 11 W 0xDE		or rd --> DW, and nack
			6'h0c : data_tx <= serv_enb_flg == 1 ? 8'h01 						: 8'h00;                // 12 W 0x01		or P Stop bit
			6'h0d : data_tx <= serv_enb_flg == 1 ? wreg_RTC_01[23:16] 		: 8'h00;						// 13 W 0xXX		or 
			6'h0e : data_tx <= 8'h00;                   															// 14 P Stop bit  or none
			6'h0f : data_tx <= 8'h00;                   															// 15 S Start bit	or none
			6'h10 : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 16 W 0xDE		or none
			6'h11 : data_tx <= serv_enb_flg == 1 ? 8'h02 						: 8'h00;                // 17 W 0x02		or none
			6'h12 : data_tx <= serv_enb_flg == 1 ? wreg_RTC_01[15:8] 		: 8'h00;						// 18 W 0xXX		or none
			6'h13 : data_tx <= 8'h00;                   															// 19 P Stop bit  or none
			6'h14 : data_tx <= 8'h00;                   															// 20 S Start bit	or none
			6'h15 : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 21 W 0xDE		or none
			6'h16 : data_tx <= serv_enb_flg == 1 ? 8'h03 						: 8'h00;                // 22 W 0x03		or none
			6'h17 : data_tx <= serv_enb_flg == 1 ? wreg_RTC_01[7:0] 			: 8'h00;						// 23 W 0xXX		or none
			6'h18 : data_tx <= 8'h00;                   															// 24 P Stop bit  or none
			6'h19 : data_tx <= 8'h00;                   															// 25 S Start bit	or none
			6'h1a : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 26 W 0xDE		or none
			6'h1b : data_tx <= serv_enb_flg == 1 ? 8'h04 						: 8'h00;                // 27 W 0x04		or none
			6'h1c : data_tx <= serv_enb_flg == 1 ? wreg_RTC_02[23:16] 		: 8'h00;						// 28 W 0xXX		or none
			6'h1d : data_tx <= 8'h00;                   															// 29 P Stop bit  or none
			6'h1e : data_tx <= 8'h00;                   															// 30 S Start bit	or none
			6'h1f : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 31 W 0xDE		or none
			6'h20 : data_tx <= serv_enb_flg == 1 ? 8'h05 						: 8'h00;                // 32 W 0x05		or none
			6'h21 : data_tx <= serv_enb_flg == 1 ? wreg_RTC_02[15:8] 		: 8'h00;						// 33 W 0xXX		or none
			6'h22 : data_tx <= 8'h00;                   															// 34 P Stop bit  or none
			6'h23 : data_tx <= 8'h00;                   															// 35 S Start bit	or none
			6'h24 : data_tx <= serv_enb_flg == 1 ? {I2C_ADDRESS[7:1],1'b0} : 8'h00;               	// 36 W 0xDE		or none
			6'h25 : data_tx <= serv_enb_flg == 1 ? 8'h06 						: 8'h00;                // 37 W 0x06		or none
			6'h26 : data_tx <= serv_enb_flg == 1 ? wreg_RTC_02[7:0] 			: 8'h00;						// 38 W 0xXX		or none
			6'h27 : data_tx <= 8'h00;                   															// 39 P Stop bit  or none
			default : data_tx <= 8'h00;                   
		endcase
	end
  
	// Sequence for data transmit bytes
	/*always@(seq_cntr, wreg_RTC_01[32])
	begin    
		case (seq_cntr)
			6'h0 : data_tx <= 8'h00;                   // 00       S                   
			6'h1 : data_tx <= {I2C_ADDRESS[7:1],1'b0}; // 01       W 0xDe
			// start of reading address
			6'h2 : data_tx <= 8'h00;                   // 02       W 0x00
			6'h3 : data_tx <= 8'h00;                   // 03       S
			6'h4 : data_tx <= {I2C_ADDRESS[7:1],1'b1}; // 04       R 0xDF
			6'h5 : data_tx <= 8'h00;                   // 05       rd --> SC
			6'h6 : data_tx <= 8'h00;                   // 06       rd --> MN
			6'h7 : data_tx <= 8'h00;                   // 07       rd --> HR
			6'h8 : data_tx <= 8'h00;                   // 08       rd --> DT
			6'h9 : data_tx <= 8'h00;                   // 09       rd --> MO
			6'ha : data_tx <= 8'h00;                   // 10       rd --> YR
			6'hb : data_tx <= 8'h00;                   // 11       rd --> DW
			6'hc : data_tx <= 8'h00;                   // 12       P
			default : data_tx <= 8'h00;                   
		endcase
	end*/
  
	// Capture rtc_01 
	always@(posedge clk)
	begin
		if (reset) 
			rtc_01 			<= 32'h00000000; 		  
		else if (rd_rtc_sc)
			rtc_01[31:24] 	<= data_rx[7:0];
		else if (rd_rtc_mn)
			rtc_01[23:16]	<= data_rx[7:0];
		else if (rd_rtc_hr)
			rtc_01[15:8] 	<= data_rx[7:0];
		else if (rd_rtc_dt)
			rtc_01[7:0]		<= data_rx[7:0];
	end

	// Capture rtc_02 
	always@(posedge clk)
	begin
		if (reset) 
			rtc_02 			<= 24'h000000; 
		else if (rd_rtc_mo)
			rtc_02[23:16]	<= data_rx[7:0];
		else if (rd_rtc_yr)
			rtc_02[15:8] 	<= data_rx[7:0];
		else if (rd_rtc_dw)
			rtc_02[7:0]		<= data_rx[7:0];
	end	
  
  // Strobe RTC ready for reading after operations completed 
	always@(posedge clk)
	begin
		if (reset)
			rtc_strb <= 1'b0; 		  
		else
			rtc_strb <= seq_strb;
	end	
  
	//Capture any errors from a nack
	always@(posedge clk)
	begin
		if (reset)
			rtc_status <= 1'b0; 		  
		else if (bus_master && tx_nack)
			rtc_status <= 1'b1; 		 
	end	 
 
endmodule
