//-----------------------------------------------------------------------------
//  Module:     DiaphragmValve_Feedback
//  Project:    
//  Version:    
//
//  Description: Implements Feedback for MagValve
//  Update: 1/13/13 Use one I2C_DV instantiation to get both plungers' adc
//				counts.
//	 Update: 1/22/13 The output mapping is now updated to reflect the Frigelli
//	 			motor design.
//	 Update: 1/31/13 We need to upgrade the speed to 200 kHz from 74.9 kHz.
//				Also, we need to strobe at 1 ms so the feedback will be available
//				for the driver.  We'll leave the label as 500 ms, but we'll feed in
//				the 1 ms strobe.        
//-----------------------------------------------------------------------------
module DiaphragmValve_Feedback
#(parameter BYPASS_STATE_DEF = 6'b101010) //2A
(  
	input              	clk,           // System Clock 
	input              	reset,         // System Reset
	input             	enable,        // System Enable
	input              	strb_frame,    // System Frame Strobe
  input               strb_load,     // Strobe to load closing limits
  
	// Reg [5:0] indicating plungers are open or close
	output	reg	[5:0]	valve_states,	// Solenoid states [J3,J4,J5,J8,J7,J6]
	// Single Flag to indicate valves are in bypass
	output 	reg       bypass_state,  
  
	// We'll set the closing limit for the plungers.
	input 			[9:0]	dv1p1_close_val, // J3
	input 			[9:0]	dv1p2_close_val, // J4
	input 			[9:0]	dv2p1_close_val, // J5
	input 			[9:0]	dv2p2_close_val, // J6
	input 			[9:0]	dv3p1_close_val, // J7
	input 			[9:0]	dv3p2_close_val, // J8
  
	// Pull the mag. valve plungers outputs to be read by serial communication.
	output 			[9:0]	DV1P1_sense, 	// U4, AIN0, SDA1, J3
	output 			[9:0]	DV1P2_sense, 	// U4, AIN1, SDA1, J4
	output 			[9:0]	DV2P1_sense, 	// U5, AIN0, SDA2, J5
	output 			[9:0]	DV2P2_sense, 	// U5, AIN1, SDA2, J6
	output 			[9:0]	DV3P1_sense,	// U8, AIN0, SDA3, J7
	output 			[9:0]	DV3P2_sense,	// U8, AIN1, SDA3, J8
  
  //I2C two wire interface. 1 = tri-state, 0 = drain at top level
  input       I2C_DV1_SCL_in,	  //  DV1 Input SCL (As Slave)
  output 		  I2C_DV1_SCL_out,  //  DV1 Output SCL (As Master)
  input       I2C_DV1_SDA_in,   //  DV1 Input SDA (Master Ack/Nack, Slave Recieve)
  output 	    I2C_DV1_SDA_out,  //  DV1 Output SDA (Master/Slave Ack/Nack)  

  input       I2C_DV2_SCL_in,   //  DV2 Input SCL (As Slave)
  output 	    I2C_DV2_SCL_out,  //  DV2 Output SCL (As Master)
  input       I2C_DV2_SDA_in,   //  DV2 Input SDA (Master Ack/Nack, Slave Recieve)
  output 	    I2C_DV2_SDA_out,  //  DV2 Output SDA (Master/Slave Ack/Nack)  
  
  input       I2C_DV3_SCL_in,   //  DV3 Input SCL (As Slave)
  output 	    I2C_DV3_SCL_out,  //  DV3 Output SCL (As Master)
  input       I2C_DV3_SDA_in,   //  DV3 Input SDA (Master Ack/Nack, Slave Recieve)
  output 	    I2C_DV3_SDA_out   //  DV3 Output SDA (Master/Slave Ack/Nack),  
);

	wire dv1p1_close; // J3
	wire dv1p2_close;	// J4
	wire dv2p1_close;	// J5
	wire dv2p2_close;	// J6
	wire dv3p1_close;	// J7
	wire dv3p2_close;	// J8

	// ADC counts from AD converters (MAX11647).
	wire [19:0] _DV1_sense;	// U4
	wire [19:0] _DV2_sense;	// U5
	wire [19:0] _DV3_sense;	// U8

  reg [9:0] dv1p1_below_close_val;
  reg [9:0] dv1p2_below_close_val;
  reg [9:0] dv2p1_below_close_val;
  reg [9:0] dv2p2_below_close_val;
  reg [9:0] dv3p1_below_close_val;
  reg [9:0] dv3p2_below_close_val;
  
  
	// Initialize sequential logic
	initial			
	begin  
    dv1p1_below_close_val <= 10'h000;
    dv1p2_below_close_val <= 10'h000;
    dv2p1_below_close_val <= 10'h000;
    dv2p2_below_close_val <= 10'h000;
    dv3p1_below_close_val <= 10'h000;
    dv3p2_below_close_val <= 10'h000;
    
		valve_states <= 6'b000000;    
    bypass_state <= 1'b0;
	end  

	// Assign plunger senses to the outputs
	// assign output = wire
	assign DV1P1_sense = _DV1_sense[9:0]; 		// U4, AIN0, SDA1, J3 
	assign DV1P2_sense = _DV1_sense[19:10];	  // U4, AIN1, SDA1, J4
	assign DV2P1_sense = _DV2_sense[9:0]; 		// U5, AIN0, SDA2, J5
	assign DV2P2_sense = _DV2_sense[19:10];	  // U5, AIN1, SDA2, J6
	assign DV3P1_sense = _DV3_sense[9:0]; 		// U8, AIN0, SDA3, J7
	assign DV3P2_sense = _DV3_sense[19:10];	  // U8, AIN1, SDA3, J8
	
	// MAG VALVE 0 PLUNGER 1 and PLUNGER 2  ************************************
	// Assuming this is U4, MAX11647
	
	// We're reading the adc counts for both plungers in one instance.
	// MAG VALVE 1 PLUNGER 1 and 2 ****
	defparam I2C_DV1_i.I2C_ADDRESS  = 8'h6C;     // Slave Address
	defparam I2C_DV1_i.I2C_SETUP    = 8'hFA;     // Sensor Setup data
	// Sensor Configuration data - Select Plunger 1 and 2
	defparam I2C_DV1_i.I2C_CONFIG   = 8'h03;     
	// 200 kHz Baud Rate, Old baud rate 74.96 kHz, h029B
	defparam I2C_DV1_i.BAUD_MASK    = 16'h00B2; // h00FA  

	I2C_DV I2C_DV1_i (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .strb_frame(strb_frame),
		
		// DV2 adc counts from sensor, 20 bits, 
		// plunger 1 from first 10 bits,
		// plunger 2 from second 10 bits.
		// J4,J3
      .DVP12_sense(_DV1_sense),	
		
      .I2C_SCL_in(I2C_DV1_SCL_in),
      .I2C_SCL_out(I2C_DV1_SCL_out),
		
		  .I2C_SDA_in(I2C_DV1_SDA_in),         
      .I2C_SDA_out(I2C_DV1_SDA_out)      
	);


	// MAG VALVE 1 PLUNGER 1 and PLUNGER 2  ************************************
	// Assuming this is U5, MAX11647

	// MAG VALVE 2 PLUNGER 1 and 2 ****
	defparam I2C_DV2_i.I2C_ADDRESS  = 8'h6C;     // Slave Address
	defparam I2C_DV2_i.I2C_SETUP    = 8'hFA;     // Sensor Setup data
	// Sensor Configuration data - Select Plunger 1 and 2
	defparam I2C_DV2_i.I2C_CONFIG   = 8'h03;     
	defparam I2C_DV2_i.BAUD_MASK    = 16'h00B2;  // Baud Rate

   I2C_DV I2C_DV2_i (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .strb_frame(strb_frame),
		
		  // J6,J5
      .DVP12_sense(_DV2_sense),
		
      .I2C_SCL_in(I2C_DV2_SCL_in),
      .I2C_SCL_out(I2C_DV2_SCL_out),
		
		  .I2C_SDA_in(I2C_DV2_SDA_in),	
      .I2C_SDA_out(I2C_DV2_SDA_out) 
   );


	// MAG VALVE 2 PLUNGER 1 and PLUNGER 2  ************************************
	// Assuming this is U8, MAX11647

	// MAG VALVE 2 PLUNGER 1 and 2 ****
	defparam I2C_DV3_i.I2C_ADDRESS  = 8'h6C;     // Slave Address
	defparam I2C_DV3_i.I2C_SETUP    = 8'hFA;     // Sensor Setup data
	// Sensor Configuration data - Select Plunger 1 and 2
	defparam I2C_DV3_i.I2C_CONFIG   = 8'h03;     
	defparam I2C_DV3_i.BAUD_MASK    = 16'h00B2;  // Baud Rate

   I2C_DV I2C_DV3_i (
      .clk(clk),
      .reset(reset),
      .enable(enable),
      .strb_frame(strb_frame),
      
		  // J8,J7
		  .DVP12_sense(_DV3_sense),
      
		  .I2C_SCL_in(I2C_DV3_SCL_in),
      .I2C_SCL_out(I2C_DV3_SCL_out),
		
      .I2C_SDA_in(I2C_DV3_SDA_in),
      .I2C_SDA_out(I2C_DV3_SDA_out)
   );
   
  //Set closed position to just less than commanded position
  always@(posedge clk)
  begin
    if (reset) begin
      dv1p1_below_close_val  <= 10'h000;
      dv1p2_below_close_val  <= 10'h000;
      dv2p1_below_close_val  <= 10'h000;
      dv2p2_below_close_val  <= 10'h000;
      dv3p1_below_close_val  <= 10'h000;
      dv3p2_below_close_val  <= 10'h000;
    end else if (strb_load) begin
      dv1p1_below_close_val  <= dv1p1_close_val - 10'h020;
      dv1p2_below_close_val  <= dv1p2_close_val - 10'h020;
      dv2p1_below_close_val  <= dv2p1_close_val - 10'h020;
      dv2p2_below_close_val  <= dv2p2_close_val - 10'h020;
      dv3p1_below_close_val  <= dv3p1_close_val - 10'h020;
      dv3p2_below_close_val  <= dv3p2_close_val - 10'h020;     
    end
  end 

	  // Decide if the diaphragm is closed or opened.
	  // The maximum input is 2.048 volt at 1024(10 bits) adc count.
	  // The LSB in this case is 2 mV.  The plunger is considered
	  // closed if the input is at 100 mV (50 counts) or higher.
	  // We used to hard code this with a constant, now we will let it
	  // be variable by connecting it to an input.  So the closed count could be
	  // variable.  
	  // Close here means the diagphram is closed, not the plunger.
	
	  // MAG VALVE 0 PLUNGER 1,2 CLOSE **
	  // 													greater than or equal to 
    assign  dv1p1_close = (_DV1_sense[9:0]		>= dv1p1_below_close_val) ?1'b1:1'b0;	// J3
	  assign  dv1p2_close = (_DV1_sense[19:10]	>= dv1p2_below_close_val) ?1'b1:1'b0; // J4

	  // MAG VALVE 1 PLUNGER 1,2 CLOSE **
															// 1 is close, 0 is open.       	
    assign  dv2p1_close = (_DV2_sense[9:0]		>= dv2p1_below_close_val) ?1'b1:1'b0;	// J5     
    assign  dv2p2_close = (_DV2_sense[19:10]	>= dv2p2_below_close_val) ?1'b1:1'b0; // J6

	  // MAG VALVE 2 PLUNGER 1,2 CLOSE **
															// 1 is close, 0 is open. 	
    assign  dv3p1_close = (_DV3_sense[9:0] 	  >= dv3p1_below_close_val) ?1'b1:1'b0;	// J7
    assign  dv3p2_close = (_DV3_sense[19:10] 	>= dv3p2_below_close_val) ?1'b1:1'b0; // J8


	//  Bypass Dialyzer -- 3 valve states  
	always@(posedge clk)
	begin
		if (reset)
			valve_states <=  6'b000000;
		else 						// MSB J3, J4, J5, J8, J7, J6 LSB
			valve_states <= {dv1p1_close, dv1p2_close, dv2p1_close, dv3p2_close, dv3p1_close, dv2p2_close};  //SUSPECT CROSS OVER
	end		 

	// Bypass state, need to look at this later.  
   always@(posedge clk)
   begin
		if (reset)
			bypass_state <=  1'b0;
    else /*if (cntr_read_P1 ==  3'h2)*/ // 
			// Bypass Dialyzer (V3P2=OPEN,.....V1P1=OPEN)
			bypass_state <= (valve_states == BYPASS_STATE_DEF)? 1'b1 : 1'b0; 
   end		 
	  

endmodule
