/*-----------------------------------------------------------------------------------
  Module:     I2C_ComPort
  
  Description: Implements I2C Interface 

  Master/Slave
  Each Device has an address
  
  
  all lines sent as open-drain. Never drive high.
  
  start condition bus pulled low while clock is high.
  stop condition bus floats high while clock is high.
  bus is considered busy from start to stop.
  data bits  when clock is low.
  
  each byte is 8 bits long. 
  each byte transmitted MSB first downto LSB.
  each byte sent must be followed by an acknolege bit from reciever.
  
  after byte during ack clock the transmitter releases SDA.
  If reciever pulls SDA low during (9th clock) then considered ACK.
  If left high then considered NACK.
  
  7 bit address followed by r/w bit (High is read, low is write).
  address byte always follows start bit.
  start bit can be used without stop bit to send information to another device.
  
  Should accept a void (start followed by stop. Not required but suggested).
  Must reset on reciept of start bit to look for address.
  
  Address 0000 reserved for general call.
  If general call followed by 06H calls for all slaves to reset.
  
  Data Speeds
  SM  100Kb
  FM  400Kb
  FM+ 1Mb
  Hs  3.4Mb
---------------------------------------------------------------------------------*/
module I2C_ComPort
#(parameter BAUD_MASK      = 16'hFFFF)    //  Baud Rate Counter  
(  
  input               clk,                //  System Clock 
  input               reset,              //  System Reset (Syncronous)
  
  input               strb_start,         //  Strobe to start if master
  input               strb_stop,          //  Strobe to stop if master
  input               strb_tx,            //  Strobe to send the byte 
  input       [7:0]   data_tx,            //  Data byte to transmit 
  output  reg         tx_cmplt,           //  Strobe that transmition is complete
  output  reg         tx_nack,            //  Flag to indicate no acknoledge from last transfer
  output  reg         bus_master,         //  Flag to indicate currently bus master
  
  input               bus_slave,          //  Flag to indicate reciever is bus_slave
  input               strb_rd,            //  Strobe to recieve the next byte on the bus
  output  reg         strb_S,             //  Strobe that an S (start has been recieved)
  output  reg         strb_P,             //  Strobe that a P (stop has been recieved)
  output  reg         strb_rx,            //  Strobe that a byte has been recieved
  output  reg [7:0]   data_rx,            //  Data byte recieved

  //I2C two wire interface. 1 = tri-state, 0 = drain at top level
  input               I2C_SCL_in,         //  Input SCL (As Slave)
  output  reg         I2C_SCL_out,        //  Output SCL (As Master)
  input               I2C_SDA_in,         //  Input SDA (Master Ack/Nack, Slave Recieve)
  output  reg         I2C_SDA_out         //  Output SDA (Master/Slave Ack/Nack)
);

    	
	reg [7:0]	  TxData;
  reg [7:0]   DataTx;  
  reg [7:0]	  RxData;
	reg [4:0]	  TxCnt;	  
  reg		      Enable_Start;
  reg		      Enable_Tx;
  reg		      Enable_Stop;  
  reg		      Enable_Rx;
  reg         Start;
  reg		      TxD;  
  reg         Stop;
  reg         Ack;
  reg         i2c_sync_clk;
  reg         byte_sending;
  reg         scl_low_Z1;
  reg         scl_low_Z2;
  reg         scl_low_Z3;
	  
  reg [7:0]   smpl_reg;
  
  reg         smpl_SDA_Z0;
  reg         smpl_SDA_Z1;
  reg         rising_SDA_strb;
  reg         falling_SDA_strb;
  
  reg         smpl_SCL_Z0;
  reg         smpl_SCL_Z1;
  reg         rising_SCL_strb;
  reg         falling_SCL_strb;
  
  wire[3:0]	  RxCnt;	
  wire        rising_SDA;
  wire        falling_SDA;    
  wire        rising_SCL;
  wire        falling_SCL;    
  
  wire        CntrEnable;
	wire		    ClearReset;  
  
  wire        TxCntIsZero;
  wire        TxCntIsOne;
  wire        TxCntIsNine;  
  
  wire		    x2DataStrb;
  wire        x4DataStrb;
  wire		    x2TxStrb;
  wire		    x2StartStrb;
  wire		    x2StopStrb;
  wire        x2RxStrb;
  wire        scl_conflict;
	wire        wait_scl;          
  
  wire        strb_trigger;
  wire        x1DataStrb;

  initial
  begin
    I2C_SCL_out       <= 1'b1;
    I2C_SDA_out       <= 1'b1;
    i2c_sync_clk      <= 1'b1;
    byte_sending      <= 1'b0;    
    TxData            <= {8{1'b0}};
    DataTx            <= {8{1'b0}};
    TxCnt             <= {5{1'b0}};
    RxData            <= {8{1'b0}};    
    TxD               <= 1'b1;
    strb_S            <= 1'b0;
    strb_P            <= 1'b0;
    strb_rx           <= 1'b0;
    data_rx           <= {8{1'b0}};
    Enable_Start      <= 1'b0;
    Enable_Tx         <= 1'b0;
    Enable_Stop       <= 1'b0;    
    Enable_Rx         <= 1'b0;
    Start             <= 1'b1;
    Stop              <= 1'b1;
    Ack               <= 1'b1;
    tx_cmplt          <= 1'b0;	
    tx_nack           <= 1'b0;
    bus_master        <= 1'b0;
    scl_low_Z1        <= 1'b0;
    scl_low_Z2        <= 1'b0;
    scl_low_Z3        <= 1'b0;
    
    smpl_reg          <= 8'h01;
    smpl_SDA_Z0       <= 1'b0;
    smpl_SDA_Z1       <= 1'b0;
    rising_SDA_strb   <= 1'b0;
    falling_SDA_strb  <= 1'b0;
    smpl_SCL_Z0       <= 1'b0;
    smpl_SCL_Z1       <= 1'b0;
    rising_SCL_strb   <= 1'b0;
    falling_SCL_strb  <= 1'b0;
    
  end



	//MASTER START TRANSMITION
	always@(posedge clk)
	begin
		if (reset) begin    
			Enable_Start <= 1'b0; 		  
		end else begin
      if (strb_start) begin
        Enable_Start <= 1'b1;
      end else if (tx_cmplt) begin
        Enable_Start <= 1'b0;		                       
      end
    end 
	end	
  
  
	//MASTER STOP TRANSMITION
	always@(posedge clk)
	begin
		if (reset) begin    
			Enable_Stop <= 1'b0; 		  
		end else begin
      if (strb_stop) begin
        Enable_Stop <= 1'b1;
      end else if (tx_cmplt) begin
        Enable_Stop <= 1'b0;		                       
      end
    end 
	end	  


	//MASTER MASTER FLAG
	always@(posedge clk)
	begin
		if (reset) begin    
			bus_master <= 1'b0; 		  
		end else begin
      if (strb_stop) begin
        bus_master <= 1'b0;
      end else if (strb_start) begin
        bus_master <= 1'b1;		                       
      end
    end 
	end	


	//MASTER BYTE TRANSMITION
	always@(posedge clk)
	begin
		if (reset) begin    
			Enable_Tx <= 1'b0; 		  
		end else begin
      if (strb_tx) begin
        Enable_Tx <= 1'b1;
      end else if (tx_cmplt) begin
        Enable_Tx <= 1'b0;		                       
      end
    end 
	end	

  // If any strobe trigger
	assign strb_trigger = strb_tx | strb_start | strb_stop | strb_rd;
  
  //Clear counter on reset or new output
	assign ClearReset = reset | strb_trigger;
  
  //Enable counter if sending a start, data or stop message
  assign CntrEnable = (Enable_Tx | Enable_Start | Enable_Stop | Enable_Rx) & ~wait_scl;
       	
	//---------------------------------------------------------------
	// Counter for one I2C clock rate
		defparam I2C_CounterX1_i.dw = 16;
		defparam I2C_CounterX1_i.max = BAUD_MASK;               
	//---------------------------------------------------------------
	Counter I2C_CounterX1_i
	(
		.clk(clk),            // Clock input 50 MHz 
		.reset(ClearReset),   // Reset
		.enable(CntrEnable),   // Enable Counter
		.cntr(),              // Counter value
		.strb(x1DataStrb)     // 1 Clk Strb when Counter == baud mask
	); 
  

	//---------------------------------------------------------------
	// Counter to get twice clock rate pulse
		defparam I2C_CounterX2_i.dw = 16;
		defparam I2C_CounterX2_i.max = {1'b0,BAUD_MASK[15:1]};               
	//---------------------------------------------------------------
	CounterSeq I2C_CounterX2_i
	(
		.clk(clk),                              // Clock input 50 MHz 
		.reset(reset),                          // Reset
		.enable(CntrEnable),                    // Enable Counter
    .start_strb(x1DataStrb | strb_trigger), // Start Strobe
		.cntr(),                                // Counter value
		.strb(x2DataStrb)                       // 1 Clk Strb when Counter == baud mask/2
	); 
  
	//---------------------------------------------------------------
	// Counter to get four times clock rate pulse
		defparam I2C_CounterX4_i.dw = 16;
		defparam I2C_CounterX4_i.max = {2'b00,BAUD_MASK[15:2]};               
	//---------------------------------------------------------------
	CounterSeq I2C_CounterX4_i
	(
		.clk(clk),                              // Clock input 50 MHz 
		.reset(reset),                          // Reset
		.enable(CntrEnable),                    // Enable Counter
    .start_strb(x1DataStrb | x2DataStrb | strb_trigger), // Start Strobe
		.cntr(),                                // Counter value
		.strb(x4DataStrb)                       // 1 Clk Strb when Counter == baud mask/4
	);   

  
  // Strobe to clock data byte information to
  assign x2TxStrb     = (x1DataStrb | x2DataStrb) & Enable_Tx;     
  
  // Strobe to clock start signal information to
  assign x2StartStrb  = (x1DataStrb | x2DataStrb) & Enable_Start;
  
  // Strobe to clock stop  signal information to
  assign x2StopStrb   = (x1DataStrb | x2DataStrb) & Enable_Stop;  
  
  // Strobe to clock data byte information to
  assign x2RxStrb     = (x1DataStrb | x2DataStrb) & Enable_Rx;
  
	//Keep track of strobe counts
	always@(posedge clk)
	begin
		if (ClearReset)    
			TxCnt <= 5'h0; 		
		else if (x2StartStrb | x2TxStrb | x2StopStrb)  
			TxCnt <= TxCnt + 1'b1;
	end	
  
  //Counter values used in logic  
  assign TxCntIsZero = ~TxCnt[4] & ~TxCnt[3] & ~TxCnt[2] & ~TxCnt[1] & ~TxCnt[0]; //5'b00000
  assign TxCntIsOne  = ~TxCnt[4] & ~TxCnt[3] & ~TxCnt[2] & ~TxCnt[1] &  TxCnt[0]; //5'b00001
  assign TxCntIsNine =  TxCnt[4] & ~TxCnt[3] & ~TxCnt[2] & ~TxCnt[1] &  TxCnt[0]; //5'b10001

	//Completed operation
	always@(posedge clk)
	begin
		if (reset) begin
			tx_cmplt <= 1'b0;
		end
		else if ((x2TxStrb && TxCntIsNine) || (x2StartStrb && TxCntIsOne) || (x2StopStrb && TxCntIsOne)) begin
			tx_cmplt <= 1'b1;
		end
		else begin
			tx_cmplt <= 1'b0;
		end
	end  
  
  //Byte Completed operation
	always@(posedge clk)
	begin
		if (reset) begin
			byte_sending <= 1'b0;
		end else if (strb_tx) begin
			byte_sending <= 1'b1;
		end else if (x4DataStrb && TxCntIsNine) begin
			byte_sending <= 1'b0;		      
		end
	end  
  
  //Start (falling edge SDA while SCL is high)
	always@(posedge clk)
	begin
		if (reset) begin
      Start <= 1'b1;      
		end
    else if ((x4DataStrb && Enable_Start && ~i2c_sync_clk) || tx_cmplt)  begin
			Start <= 1'b1;  
		end
		else if (x4DataStrb && Enable_Start && i2c_sync_clk) begin
			Start <= 1'b0;  
		end
	end    
  
  //Stop (rising edge SDA while SCL is high)
	always@(posedge clk)
	begin
		if (reset) begin
      Stop <= 1'b1;      
		end
    else if (x4DataStrb && Enable_Stop && i2c_sync_clk)  begin
			Stop <= 1'b1;  
		end
		else if (x4DataStrb && Enable_Stop && ~i2c_sync_clk) begin
			Stop <= 1'b0;  
		end
	end     
    
  //Clock change state every 2xDataStrb 
  always@(posedge clk)
  begin
    if (reset) begin
      i2c_sync_clk <= 1'b1;
    end else if (strb_tx || strb_start || strb_stop || strb_rd) begin
      i2c_sync_clk <= 1'b0;
    end else if ((x2TxStrb && byte_sending) || (x2StopStrb && TxCntIsZero) || (x2StartStrb && TxCntIsZero) || x2RxStrb) begin
      i2c_sync_clk <= ~i2c_sync_clk;
    end else if (tx_cmplt || strb_rx) begin
      i2c_sync_clk <= 1'b1;
    end
  end  
  
  //Store data to shift out on write
  always@(posedge clk)
  begin
    if (reset)
      DataTx <= 8'h00;
    else if (strb_tx)
      DataTx <= data_tx;
  end
  
	//Capture and shift the data out MSB first
	always@(posedge clk)
	begin
		if (reset) begin
			TxData <= {8{1'b0}};
      TxD <= 1'b1;      
		end
    else if (x2StartStrb && i2c_sync_clk) begin
			TxData <= {8{1'b0}};
      TxD <= 1'b0; 
    end
    else if (x4DataStrb && TxCntIsZero && Enable_Tx)  begin
			TxData <= {DataTx[6:0],1'b1}; //Tri-state 9th bit for ack/nack			
      TxD <= DataTx[7];
		end
		else if (x4DataStrb && Enable_Tx && ~i2c_sync_clk) begin
			TxData[7:1] <= TxData[6:0];
      TxD <= TxData[7];
		end
	end

	//Check for ack/nack on transmit from slave
	always@(posedge clk)
	begin
		if (ClearReset)    
			tx_nack <= 5'h0; 		
		else if (x4DataStrb && TxCntIsNine && Enable_Tx)  
			tx_nack <= I2C_SDA_in;
	end	  
  

  // Output clock Syncronized
  always@(posedge clk)
  begin        
  if (reset)
    I2C_SCL_out <= 1'b1;
  else
    I2C_SCL_out <= i2c_sync_clk;
  end
  
  //If master clock is tri-stated but slave is pulling it low for more than two clocks then
  assign scl_conflict = i2c_sync_clk & ~I2C_SCL_in & bus_master;
  
  //Check three clocks worth of SCL conflict
  always@(posedge clk)
  begin        
    if (reset) begin
      scl_low_Z1 <= 1'b0;
      scl_low_Z2 <= 1'b0;
      scl_low_Z3 <= 1'b0;
    end else begin
      scl_low_Z1 <= scl_conflict;
      scl_low_Z2 <= scl_low_Z1;
      scl_low_Z3 <= scl_low_Z2;
    end
  end
  
  // If conflicted SCL for more than two clocks
  assign wait_scl = scl_low_Z1 & scl_low_Z2 & scl_low_Z3;

  // Output Data
  always@(posedge clk)
  begin        
    if (reset)
      I2C_SDA_out <= 1'b1;
    else
      I2C_SDA_out <= TxD & Start & Stop & Ack;
  end
  
//------------------------------------------------------------------------------
//    RECIEVE BYTES
//------------------------------------------------------------------------------  
  
  // Shift register to downsample SDA
  always@(posedge clk)
  begin        
    if (reset) begin
      smpl_reg      <= 8'h01;
    end else begin
      smpl_reg[7:1] <= smpl_reg[6:0];
      smpl_reg[0]   <= smpl_reg[7];
    end
  end  
  
  // Use two samples spaced 8 clocks apart to detect edges
  always@(posedge clk)
  begin
    if (reset) begin
      smpl_SDA_Z0 <= 1'b1;
      smpl_SDA_Z1 <= 1'b1;
    end else if (smpl_reg[1]) begin
      smpl_SDA_Z0 <= I2C_SDA_in;
      smpl_SDA_Z1 <= smpl_SDA_Z0;
    end
  end
  
  // Logic for rising and falling edges
  assign rising_SDA  =  smpl_SDA_Z0 & ~smpl_SDA_Z1;
  assign falling_SDA = ~smpl_SDA_Z0 &  smpl_SDA_Z1;
  
  // Rising edge strobe of SDA inputs (Only in slave mode)
  always@(posedge clk)
  begin
    if (reset) begin
      rising_SDA_strb  <= 1'b0;
    end else if (smpl_reg[2] && rising_SDA) begin
      rising_SDA_strb  <= 1'b1;
    end else begin
      rising_SDA_strb  <= 1'b0;
    end
  end  
  
  
  // Falling edge strobe of SDA inputs (Only in slave mode)
  always@(posedge clk)
  begin
    if (reset) begin
      falling_SDA_strb <= 1'b0;
    end else if (smpl_reg[2] && falling_SDA) begin
      falling_SDA_strb  <= 1'b1;
    end else begin
      falling_SDA_strb  <= 1'b0;
    end
  end    
  
  // Detect a Start Command
  always@(posedge clk)
  begin
    if (reset)
      strb_S <= 1'b0;
    else
      strb_S  <= falling_SDA_strb & I2C_SCL_in & bus_slave;
  end
  
  // Detect a Stop Command
  always@(posedge clk)
  begin
    if (reset)
      strb_P <= 1'b0;
    else
      strb_P  <= rising_SDA_strb & I2C_SCL_in & bus_slave;
  end  
  
  // Use two samples spaced 8 clocks apart to detect edges
  always@(posedge clk)
  begin
    if (reset) begin
      smpl_SCL_Z0 <= 1'b1;
      smpl_SCL_Z1 <= 1'b1;
    end else if (smpl_reg[1]) begin
      smpl_SCL_Z0 <= I2C_SCL_in;
      smpl_SCL_Z1 <= smpl_SCL_Z0;
    end
  end
  
  // Logic for rising clock edge
  assign rising_SCL  =  smpl_SCL_Z0 & ~smpl_SCL_Z1;
  assign falling_SCL = ~smpl_SCL_Z0 &  smpl_SCL_Z1;
  
  // Rising edge strobe of SDA inputs (Only in slave mode)
  always@(posedge clk)
  begin
    if (reset) begin
      rising_SCL_strb  <= 1'b0;
    end else if (smpl_reg[2] && rising_SCL) begin
      rising_SCL_strb  <= 1'b1;
    end else begin
      rising_SCL_strb  <= 1'b0;
    end
  end 
  
  // Falling edge strobe of SDA inputs (Only in slave mode)
  always@(posedge clk)
  begin
    if (reset) begin
      falling_SCL_strb  <= 1'b0;
    end else if (smpl_reg[2] && falling_SCL) begin
      falling_SCL_strb  <= 1'b1;
    end else begin
      falling_SCL_strb  <= 1'b0;
    end
  end   
     
  
	//---------------------------------------------------------------
	// Counter to get twice clock rate pulse
		defparam I2C_RxCounter_i.dw = 4;
		defparam I2C_RxCounter_i.max = 4'h9;               
	//---------------------------------------------------------------
	CounterSeq I2C_RxCounter_i
	(
		.clk(clk),                              // Clock input 50 MHz 
		.reset(reset),                          // Reset
		.enable(rising_SCL_strb),               // Enable Counter
    .start_strb(strb_rd),                   // Start a recieve sequence
		.cntr(RxCnt),                           // Counter value
		.strb()                                 // 1 Clk Strb when Counter == baud mask/4
	);  
  
	//Completed operation
	always@(posedge clk)
	begin
		if (reset) begin
			strb_rx <= 1'b0;
		end
		else if (x2RxStrb && RxCnt == 4'h9) begin
			strb_rx <= 1'b1;
		end
		else begin
			strb_rx <= 1'b0;
		end
	end    


	//RECIEVE ENABLE
	always@(posedge clk)
	begin
		if (reset) begin    
			Enable_Rx <= 1'b0; 		  
		end else begin
      if (strb_rd) begin
        Enable_Rx <= 1'b1;
      end else if (strb_rx) begin
        Enable_Rx <= 1'b0;		                       
      end
    end 
	end	   
  
	//RECIEVE BYTE MSB FIRST
	always@(posedge clk)
	begin
		if (reset) begin
			RxData <= {8{1'b0}};
		end
    else if (strb_rd) begin
			RxData <= {8{1'b0}};
    end
		else if (rising_SCL_strb && Enable_Rx) begin
			RxData[7:1] <= RxData[6:0];
      RxData[0]   <= I2C_SDA_in;
		end
	end  
    
  //RECIEVED BYTE
  always@(posedge clk)
	begin
		if (reset)
			data_rx <= {8{1'b0}};
    else if (falling_SCL_strb && RxCnt == 4'h8)
			data_rx <= RxData;
	end  
  
  //ACK
	always@(posedge clk)
	begin
		if (reset) begin
      Ack <= 1'b1;      
		end
    else if (strb_rx)  begin
			Ack <= 1'b1;  
		end
		else if (falling_SCL_strb && RxCnt == 4'h8) begin
			Ack <= 1'b0;  
		end
	end      
    
    
endmodule
