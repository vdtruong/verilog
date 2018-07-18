/*-----------------------------------------------------------------------------
  Module:     I2C_DV
  
  Description: Implements I2C Interface for DV
  Update: 		1/9/13, Change to capture AIN0 and AIN1 consecutively in one
					read.

-----------------------------------------------------------------------------*/
module I2C_DV
#(parameter I2C_ADDRESS  = 8'h36,      //  Address for slave I2C Mag Valve sensor
  parameter I2C_SETUP    = 8'hFA,      //  Setup data for sensor, old - 8'hEC 
  parameter I2C_CONFIG   = 8'h03,      //  Configuration data for sensor, old - 8'h61 
  parameter BAUD_MASK    = 16'h00C7)	//  Baud Rate Counter  250KHz bus rate
(  
  //System Inputs
  input               	clk,    		//  System Clock 
  input               	reset,      //  System Reset (Syncronous)  
  input               	enable,     //  Enable this interface
  input               	strb_frame, //  500ms Strobe
  
  //DV output
  //  DV adc counts read from sensor for both plungers.
  output reg	[19:0]	DVP12_sense,        
  //  output reg          	DVP12_status, //  DV sensor status
  //  output reg          	DVP12_strb,   //  Strobe that new DV adc counts are ready
  
  //I2C two wire interface. 1 = tri-state, 0 = drain at top level
  input               I2C_SCL_in, 	//  Input SCL (As Slave)
  output              I2C_SCL_out,  //  Output SCL (As Master)
  input               I2C_SDA_in,   //  Input SDA (Master Ack/Nack, Slave Recieve)
  output              I2C_SDA_out   //  Output SDA (Master/Slave Ack/Nack)
);

  reg         strb_frameZ1;
  reg         seq_enable;
  reg  [19:0] DVP12_sense_word;
  //reg         DVP12_error;
  
  wire        strb_rx;
  wire        tx_cmplt;
  
  wire        strb_start;
  wire        strb_stop;
  wire        strb_tx;
  reg  [7:0]  data_tx;
  wire [7:0]  data_rx;
  wire        strb_rd;
  //wire        bus_master;
  //wire        tx_nack;     
  
  wire        rd_DV_P1_uppr_byte;
  wire        rd_DV_P1_lwr_byte;
  
  wire        rd_DV_P2_uppr_byte;
  wire        rd_DV_P2_lwr_byte;
  
  wire        next_op_strb;
  wire        seq_strb;
  wire [4:0]  seq_cntr;

  initial
  begin
    strb_frameZ1     <= 1'b0;
    DVP12_sense      <= 20'h00000;
	  DVP12_sense_word <= 20'h00000;
    //	 DVP12_error      <= 1'b0;
    //    DVP12_status     <= 1'b0;
    //    DVP12_strb       <= 1'b0;    
    seq_enable       <= 1'b0;
  end

  //-----------------------------------------------------------------------------------------
  // I2C Com Port Interfaec for the I2C bus
  defparam I2C_ComPort_i.BAUD_MASK = BAUD_MASK;
  //-----------------------------------------------------------------------------------------
  I2C_ComPort I2C_ComPort_i(  
	 // inputs
    .clk(clk),                  //  System Clock 
    .reset(reset),              //  System Reset (Syncronous)
    .strb_start(strb_start),    //  Input Strobe to start if master
    .strb_stop(strb_stop),      //  Input Strobe to stop if master
    .strb_tx(strb_tx),          //  Input Strobe to send the byte 
    .data_tx(data_tx),          //  Input [7:0] Data byte to transmit 
	 // outputs
    .tx_cmplt(tx_cmplt),        //  Output Strobe that transmition is complete
    .tx_nack(),          //  Output Flag to indicate no acknoledge from last transfer
    .bus_master(),    //  Output Flag to indicate currently bus master  
	 // inputs
    .bus_slave(1'b0),           //  Input Flag to indicate reciever is bus_slave
    .strb_rd(strb_rd),          //  Input Strobe to recieve the next byte on the bus
	 // outputs
    .strb_S(),                  //  Output Strobe that an S (start has been recieved)
    .strb_P(),                  //  Output Strobe that a P (stop has been recieved)
    .strb_rx(strb_rx),          //  Output Strobe that a byte has been recieved
    .data_rx(data_rx),          //  Output Data byte recieved  
	 
    .I2C_SCL_in(I2C_SCL_in),    //  Input SCL (As Slave)
    .I2C_SCL_out(I2C_SCL_out),  //  Output SCL (As Master)
    .I2C_SDA_in(I2C_SDA_in),    //  Input SDA (Master Ack/Nack, Slave Recieve)
    .I2C_SDA_out(I2C_SDA_out)   //  Output SDA (Master/Slave Ack/Nack)
  );


  //Enable Sequence
  always@(posedge clk)
    begin
      if (reset | seq_strb)
			seq_enable <= 1'b0; 		  
      else if (strb_frame)
			seq_enable <= 1'b1; 		      
    end	


	//---------------------------------------------------------------
	// Sequence Counter for DV1 Sensor sequence of operations
		defparam CounterSeq_i.dw 	= 5;
		defparam CounterSeq_i.max 	= 5'h0f;
	//---------------------------------------------------------------
	CounterSeq CounterSeq_i
	(
		.clk(clk),                 // Clock input 50 MHz 
		.reset(reset),             // Reset
		.enable(next_op_strb),     // Enable Operation
		.start_strb(strb_frame),   // Start Strobe every 500 ms
		// outputs
		.cntr(seq_cntr),           // Sequence counter value
		.strb(seq_strb)       		// Strobe when sequence is complete
	); 

	// Delay 500ms strobe by 1 clock
	always@(posedge clk)
	begin
	if (reset)
		strb_frameZ1 <= 1'b0; 		  
	else
		strb_frameZ1 <= strb_frame;
	end	


  // Strobe to move to next operation in sequence
  assign next_op_strb = (strb_frameZ1 | tx_cmplt | strb_rx) & seq_enable;  

  // 00, 05
  assign strb_start   = next_op_strb & ((seq_cntr == 5'h00) | (seq_cntr == 5'h05));
  
  // 04, 0b
  assign strb_stop    = next_op_strb & ((seq_cntr == 5'h04) | (seq_cntr == 5'h0b));
  
  // Read DV Plunger 2 upper byte.  Delay by one sequence count for all reads.
  assign rd_DV_P2_uppr_byte  = strb_rx & (seq_cntr == 5'h08);
  
  // Read DV Plunger 2 lower byte.
  assign rd_DV_P2_lwr_byte   = strb_rx & (seq_cntr == 5'h09);
  
  // Read DV Plunger 1 upper byte.
  assign rd_DV_P1_uppr_byte  = strb_rx & (seq_cntr == 5'h0a);
  
  // Read DV Plunger 1 lower byte.
  assign rd_DV_P1_lwr_byte   = strb_rx & (seq_cntr == 5'h0b);
  
  // Reading using external clock with AIN0 and AIN1 respectively.
  // AIN0 and AIN1 have two bytes each.  AIN0 is for plunger 2 and
  // AIN1 is for plunger 1.
  // External clock means we are using SCL instead of the adc's internal
  // clock.
  assign strb_rd = next_op_strb & (seq_cntr == 5'h07 | seq_cntr == 5'h08 | 
											  seq_cntr == 5'h09 | seq_cntr == 5'h0a);
  
  // 01, 02, 03, 06 
  assign strb_tx = next_op_strb & ~strb_start & ~strb_stop & ~strb_rd;
  
  // Sequence for data transmit bytes
  always@(seq_cntr)
  begin    
    case (seq_cntr)
      5'h00 : data_tx <= 8'h00;                   // 00  S Start bit                  
      5'h01 : data_tx <= {I2C_ADDRESS[7:1],1'b0}; // 01  W 0x6C - write
      5'h02 : data_tx <= {I2C_SETUP};             // 02  W varies
      5'h03 : data_tx <= {I2C_CONFIG};            // 03  W varies
      5'h04 : data_tx <= 8'h00;                   // 04  P Stop bit
      5'h05 : data_tx <= 8'h00;                   // 05  S Start bit
      5'h06 : data_tx <= {I2C_ADDRESS[7:1],1'b1}; // 06  W 0x6D - read
      5'h07 : data_tx <= 8'h00;           	// 07  rd --> Plgr2 Upper (2bits), J3
      5'h08 : data_tx <= 8'h00;              // 08  rd --> Plgr2 Lower (8bits), J3
      5'h09 : data_tx <= 8'h00;              // 09  rd --> Plgr1 Upper (2bits), J4
      5'h0a : data_tx <= 8'h00;              // 0a  rd --> Plgr1 Lower (8bits), J4      
      5'h0b : data_tx <= 8'h00;              // 0b  P Stop bit
      5'h0c : data_tx <= 8'h00;              // 0c  Sleep until next trigger
      5'h0d : data_tx <= 8'h00;              // 0d  NA
      5'h0e : data_tx <= 8'h00;              // 0e  NA
      5'h0f : data_tx <= 8'h00;              // 0f  NA
      default : data_tx <= 8'h00;                   
    endcase
  end
    
	// Capture DV adc counts.
	always@(posedge clk)
	begin
		if (reset) 
			DVP12_sense_word 				    <= 20'h00000; 		  
		else if (rd_DV_P2_uppr_byte)
			DVP12_sense_word[9:8] 		  <= data_rx[1:0];
		else if (rd_DV_P2_lwr_byte)
      DVP12_sense_word[7:0] 		  <= data_rx;	  
		else if (rd_DV_P1_uppr_byte)
			DVP12_sense_word[19:18]		  <= data_rx[1:0];
		else if (rd_DV_P1_lwr_byte)
      DVP12_sense_word[17:10] 	  <= data_rx;
		else
			DVP12_sense_word 				    <= DVP12_sense_word;
	end	
  
  // Update port output only at end of sequence and no nacks
  always@(posedge clk)
  begin
	if (reset)
		DVP12_sense <= 20'h00000;
	else if (seq_strb /*&& ~DVP12_error*/)
		DVP12_sense <= DVP12_sense_word;
  end
  
//  //Capture any errors from a nack
//  always@(posedge clk)
//	begin
//	  if (reset || strb_frame)
//      DVP12_error <= 1'b0; 		  
//	  else if (bus_master && tx_nack)
//      DVP12_error <= 1'b1; 		 
//	end	    
  
// Strobe DV1P12 ready for reading after operations completed 
//	always@(posedge clk)
//	begin
//	  if (reset)
//	    DVP12_strb <= 1'b0; 		  
//	  else
//       DVP12_strb <= seq_strb;
//	end	
  
// Capture any errors from a nack
//  always@(posedge clk)
//	begin
//	  if (reset)
//	    DVP12_status <= 1'b0; 		  
//	  else if (bus_master && tx_nack)
//       DVP12_status <= 1'b1; 		 
//	end	  
    
endmodule
