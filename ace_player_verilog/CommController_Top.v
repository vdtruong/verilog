//-----------------------------------------------------------------
//  Module:     CommController_Top
//  Project:    CommController Top Level
//  Version:    0.01-1
//
//  Description: Implements the top level module.
//
//
//----------------------------------------------------------------- 
module CommController_Top 
//-----------------FPGA VERSION------------------------------------------------------
#(parameter X_FPGA_VERSION = 16'h0003)    
//----------------END FPGA VERSION---------------------------------------------------  
(
  input  CLK_COM,                       // Input system clock
  input  COM_LOGICRESET_N,              // Logic reset active low input
    
  output CONFIG_TARGET,                 // Cause connected FPGA hard reset        

  output UP_LINK_LED_N,                 // Status LED for uplinkg
  output DWN_LINK_LED_N,                // Status LED for downlink
  output COM_STATUS_N,

  input  BRD_TYPE_0,                    // Discrete to indicate board type
  input  BRD_TYPE_1,                    // Discrete to indicate board type
  input  BRD_TYPE_2,                    // Discrete to indicate board type
  input  BRD_TYPE_3,                    // Discrete to indicate board type
  input  BRD_REV_0,                     // Discrete to indicate board revision
  input  BRD_REV_1,                     // Discrete to indicate board revision
  input  BRD_REV_2,                     // Discrete to indicate board revision
  input  BRD_REV_3,                     // Discrete to indicate board revision
  input  BRD_PARITY,                    // Discrete to indicate board discrete parity (odd)
   
  output UPLINK_TX,                     // Uplink to master IO serial transmit
  input  UPLINK_RX,                     // Uplink to master IO serial recieve

  output reg DWNLINK_TX_X_RX,           // Downlink to slave device recieve
  input  DWNLINK_RX_X_TX,               // Downlink to slave device transmit

  output TEST1_TX,                      // Test serial bus transmit
  input  TEST1_RX,                      // Test serial bus recieve

  input  X_READY,                       // Ready signal from slave device
  input  X_DISCRETE1,                   // Normally high discrete from slave device
  input  X_DISCRETE2,                   // Normally low discrete from slave device
  output X_LOGIC_RESET_N,               // Slave device logic reset

  output JTAG_X_TMS,                    // Slave device JTAG TMS
  output JTAG_X_TDI,                    // Slave device JTAG TDI
  input  JTAG_X_TDO,                    // Slave device JTAG TDO
  output JTAG_X_TCK,                    // Slave device JTAG TCK
  input  JTAG_X_DETECT_N                // Slave device JTAG Cable Detection 
  
	// Following for simulation purpose only, comment out when done.
//	output 			load_ace_pull,
//	output [7:0]	dataout_a_pull,
//	output			wr_strb_z2_pull,
//	output			wr_strb_z3_pull,
//	output			wr_strb_z4_pull,
//	output			wr_strb_z5_pull,
//	output [7:0]	datain_b_pull,
//	output			rd_ram_strb_pull,
//	output [9:0]  	addr_a_pull,	  
//	output [9:0]  	addr_b_pull
);
    						
	localparam RAMWIDTH 	= 10;				// Block Ram word width				 
  
	//Module connections
  	wire        			clk;           // System Clock
  	wire        			reset;         // Logic Reset
  	wire 		  				strb_500ms;    // 500 ms Strobe
  	wire 		  				strb_250ms;    // 250 ms Strobe
  
  	reg 	[35:0]  	  rd_data;       // Data read
  	wire        			rd_strb;       // Read Register Strobe
  	wire 	[3:0]  			rd_addr;       // Address to read from
  	wire 	[3:0]  			wr_addr;       // Address to write to
  	wire        			wr_strb;       // Write Register Strobe
  	wire 	[35:0]			wr_data;       // Data to write 
  	wire 	[1:0]				comm_err;      // Communication Error  

  	wire        			COM_test_rx;   // connects route switch to UART - Registers Rx
  	wire        			COM_test_tx;   // connects route switch to UART - Registers Tx
  	wire        			X_sw1_tx;      // X routing switch1
  	wire        			X_sw2_tx;      // X routing switch2
  
  	wire        			sw_route_thru;	// Signal to set up route through or test mode
   
  	// wires for AcePlayer	  
   wire        			rdy;
   wire        			error;
   wire        			eof_done;							  
   //wire						clk_ace;			// clock for ace player	
   wire       				done_ld_ace;	// done stretching for load_ace					
     
 	// wires for fifo controller					 
  	wire [RAMWIDTH-1:0]  addr_a;     	// output address, read addr
  	wire [RAMWIDTH-1:0]  addr_b;     	// input address, write addr	 
	wire						fifo_empty;
	wire						fifo_full;		 
	wire						fifo_half;		
	
 	// wires for block ram
  	wire [7:0] 				dataout_a;  	// data output
		
   // For ace player wires
   wire                 JTAG_X_TMS_ace;
   wire                 JTAG_X_TCK_ace;
   wire                 JTAG_X_TDI_ace;	 
														 										
	// Map Registers ////////////////////////////////////////////////////
	// Write Registers
  	reg [35:0]           reg_wr_00;  // Register 0 to write
	// Register 1 to write, write one to set the JTAG outputs to tri-state.
  	reg [35:0]           reg_wr_01;  							 
	// Register 2 to write, reset of ACE player serial transfer
  	reg [35:0]           reg_wr_02;
	// Register 3 to write, clear FIFO
  	reg [35:0]           reg_wr_03;
	// Register 4 to write, 4 bytes for Block Ram.
  	reg [35:0]           reg_wr_04;
	
	// Read Registers
  	reg [35:0]           reg_rd_00;	// Register 0 to read
  	reg [35:0]           reg_rd_01; 	// Register 1 to read (version)
	// Register 2 to read for status of fifo and Ace Player.		
	// Bit 0 - fifo_empty											  		
	// Bit 1 - fifo_full												  		
	// Bit 2 - fifo_half	 											  		
	// Bit 3 - Ace Player Error											  		
	// Bit 4 - Ace Player EOF Done
  	reg [35:0]           reg_rd_02;                
  	// End of Map Registers ////////////////////////////////////////////////////			 
  	
	// Other Registers declarations	 
  	reg  		   led_output;						// LED Toggle
  	
	  reg         rd_strb_Z1;               	// Read strobe delay 1
  	reg         rd_strb_Z2;               	// Read strobe delay 2
  
  	reg         endpoint_logic_reset_n;   	// Active low reset for slave device
  	reg        	endpoint_config_n;        	// Active low configuration for slave device
  	reg [15:0]  start_seq_shift_reg;      	// Startup Sequence shift register	
	  reg			almost_empty;					// Indicates that the fifo is almost empty									 
	  reg			almost_empty_z1;				// delayed version			
  
	// For AcePlayer																	
	reg			rdy_z1;				// delay of rdy							
	reg			rdy_z2;				// delay of rdy_z1							
	reg			rdy_z3;				// delay of rdy_z2							
	reg			rdy_z4;				// delay of rdy_z3							
	reg			rdy_z5;				// delay of rdy_z4							
	reg			rdy_z6;				// delay of rdy_z5							
	reg			rdy_z7;				// delay of rdy_z6
   reg        	load;       		// first strobe to stretch the load_ace
   reg        	load_ace;      	// strobe to load data to ace player
	// For fifo controller
	reg			rd_ram_strb;		// strobe to read ram
	reg			rd_ram_strb_z1;	// delay					
	reg			rd_ram_strb_z2;	// delay					
	reg			rd_ram_strb_z3;	// delay					
	reg			rd_ram_strb_z4;	// delay	 
	reg			fifo_empty_z1;		// delay	 
	reg			fifo_empty_z2;		// delay	 
	reg			fifo_empty_z3;		// delay	 
	reg			fifo_empty_z4;		// delay	 
	reg			fifo_empty_z5;		// delay	 
	reg			fifo_empty_z6;		// delay		
	// For block ram											  
  	reg [7:0] 	datain_b;   		// data to write port B			
	// Need to pack the Fifo four times for each wr_data from
	// serial input.
	// One clock later for RAM wr_b strobe
  	reg        	wr_strb_z1;    										  
	// Two clocks later for RAM wr_b strobe
  	reg        	wr_strb_z2;					  
	// Three clocks later for RAM wr_b strobe
  	reg        	wr_strb_z3;
	// Four clocks later for RAM wr_b strobe
  	reg        	wr_strb_z4;
	// Five clocks later for RAM wr_b strobe
  	reg        	wr_strb_z5;	
	// Six clocks later for RAM wr_b strobe
  	reg        	wr_strb_z6;
	// Seven clocks later for RAM wr_b strobe
  	reg        	wr_strb_z7;	
	// Eight clocks later for RAM wr_b strobe
  	reg        	wr_strb_z8;	
	// Nine clocks later for RAM wr_b strobe
  	reg        	wr_strb_z9;				
	// For General clock generator
	//reg	 		strt_ace_clk_strb;
	  //reg			COM_LOGICRESET_N_z1;
		  
  //Initialize sequential logic
  initial     
  	begin
    	reg_wr_00              	<= {36{1'b0}};
    	reg_wr_01              	<= {36{1'b0}};
    	reg_wr_02              	<= {36{1'b0}};	
    	reg_wr_03              	<= {36{1'b0}};
    	reg_wr_04              	<= {36{1'b0}};
		 
    	reg_rd_00              	<= {36{1'b0}};
    	reg_rd_01              	<= {36{1'b0}};
    	reg_rd_02              	<= {36{1'b0}}; 
		 
    	led_output             	<= 1'b0;
    	endpoint_logic_reset_n 	<= 1'b0;
    	endpoint_config_n      	<= 1'b0;
    	start_seq_shift_reg    	<= 16'b0000;
    	DWNLINK_TX_X_RX        	<= 1'b1;
    	load                   	<= 1'b0;
    	load_ace               	<= 1'b0;		 
    	datain_b               	<= {8{1'b0}};	 
    	wr_strb_z1       			  <= 1'b0;		 
    	wr_strb_z2       			  <= 1'b0;		 
    	wr_strb_z3       			  <= 1'b0;		 
    	wr_strb_z4       			  <= 1'b0;		 
    	wr_strb_z5       			  <= 1'b0;			 
    	wr_strb_z6       			  <= 1'b0;		 
    	wr_strb_z7       			  <= 1'b0;		 
    	wr_strb_z8       			  <= 1'b0;		 
    	wr_strb_z9       			  <= 1'b0;
      rd_strb_Z1              <= 1'b0;  
      rd_strb_Z2              <= 1'b0; 
    	rdy_z1       				    <= 1'b0;		 
    	rdy_z2       				    <= 1'b0;		 
    	rdy_z3       				    <= 1'b0;		 
    	rdy_z4       				    <= 1'b0;		 
    	rdy_z5       				    <= 1'b0;		 
    	rdy_z6       				    <= 1'b0;		 
    	rdy_z7       				    <= 1'b0;		 
    	rd_ram_strb   				  <= 1'b0;		 
    	rd_ram_strb_z1				  <= 1'b0;		 
    	rd_ram_strb_z2				  <= 1'b0;		 
    	rd_ram_strb_z3				  <= 1'b0;		 
    	rd_ram_strb_z4				  <= 1'b0;		 
    	//strt_ace_clk_strb			<= 1'b0;		 
    	//COM_LOGICRESET_N_z1		  <= 1'b0;		 
    	fifo_empty_z1				    <= 1'b0;		 
    	fifo_empty_z2				    <= 1'b0;		 
    	fifo_empty_z3				    <= 1'b0;		 
    	fifo_empty_z4				    <= 1'b0;		 
    	fifo_empty_z5				    <= 1'b0;		 
    	fifo_empty_z6				    <= 1'b0;	 
    	almost_empty				    <= 1'b0;		 
    	almost_empty_z1			    <= 1'b0;	
	end
  
  
//   // Set up an internal clock from the external clock.
//   // This is necessary for the Ace Player to be laid out
//   // sucessfully.
//   //CLKINT U2 (.Y(clk), .A(CLK_COM));
//   CLKINT CLKINT_i1 
//   (  
//      .Y(clk), 
//      .A(CLK_COM)
//   );  
  
  
  // Clock input and reset scheme  
  PLL_System_Clock PLL_System_Clock_i
  (  
    .clk_sys(CLK_COM),                    // Input System Clock 
    .async_reset(COM_LOGICRESET_N),       // Input System Reset (Asyncronous) active low 
  
    .sync_reset(reset),                   // System Reset (Synchronous) active high
    .clk(clk)                             // System Clock
  );   
  

//  // Clock input for ACE Player  
//  PLL_1MHz PLL_1MHz_i
//  (
//    .clk(clk),
//    .enable(1'b1),
//    .clk_1MHz(clk_ace)
//  );   
   
   
   // Tri-state them or use the outputs from the ace player.
  assign   JTAG_X_TMS  = (reg_wr_01[0] == 1'b1)? JTAG_X_TMS_ace : 1'bZ; 
	assign   JTAG_X_TDI  = (reg_wr_01[0] == 1'b1)? JTAG_X_TDI_ace : 1'bZ;
	assign   JTAG_X_TCK  = (reg_wr_01[0] == 1'b1)? JTAG_X_TCK_ace : 1'bZ;   
   
	// for simulation only, comment out when done
//	assign load_ace_pull 	= load_ace;
//	assign dataout_a_pull 	= dataout_a;
//	assign wr_strb_z2_pull 	= wr_strb_z2;
//	assign wr_strb_z3_pull 	= wr_strb_z3;
//	assign wr_strb_z4_pull 	= wr_strb_z4;
//	assign wr_strb_z5_pull 	= wr_strb_z5;
//	assign datain_b_pull 	= datain_b;	 
//	assign rd_ram_strb_pull = rd_ram_strb;
//	assign addr_a_pull 		= addr_a;	  
//	assign addr_b_pull 		= addr_b;
  
  //---------------------------------------------------------------
  // 500ms Strobe 
    defparam Strobe500ms_i.dw = 25;
    defparam Strobe500ms_i.max = 25'h17D7840;
  //---------------------------------------------------------------
  Counter Strobe500ms_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_500ms)     // 1 Clk Strb when Counter == max 500 ms
  );      
  
  	//---------------------------------------------------------------
  	// Toggle LED : Change state every 1 sec if enabled by the switch
  	//---------------------------------------------------------------
  	always@(posedge clk)
  	begin
  		if (reset) begin    
      	led_output <= 1'b0;
   	end 
   	else if (strb_500ms) begin 
		  	led_output <= ~led_output;
    	end
  	end
                         
  //  Use uplink to indicate pass thru to LVDS and usable test port.
  assign UP_LINK_LED_N  = reg_rd_00[14]; 
  //  Use downlink to indicate pass thru to test port.
  assign DWN_LINK_LED_N = ~reg_rd_00[14]; 
  //  Assign LED Status to toggle at 1 sec period.
  assign COM_STATUS_N   = led_output;            
    
  //---------------------------------------------------------------	
  // COM PORT TEST 921600, 8, E, 1
  //---------------------------------------------------------------
   defparam COM_Port_Test_i.ascii_prompt 	= 8'h78;    // x
   defparam COM_Port_Test_i.BAUD_MASK 		= 16'h0035;
	 defparam COM_Port_Test_i.BAUD_QUALIFY 	= 16'h0024;
   defparam COM_Port_Test_i.PARITY_BIT 	= 1'b1;
   defparam COM_Port_Test_i.CLEAR_ON_IDLE = 1'b0;
   defparam COM_Port_Test_i.ADDR_DW 		= 4;    
   defparam COM_Port_Test_i.ECHO_ON 		= 1'b1;
	CommControlSlave COM_Port_Test_i  
  (  
    .clk(clk),                // System Clock 
    .reset(reset),            // System Reset (Syncronous) 
    .enable(1'b1),            // Enable COM
    .rx_en(1'b1),  	         // Recieve enable
    .rx(COM_test_rx),         // Data recieve bit
    .tx(COM_test_tx),         // Tx bit to send out on pin
    .tx_en(),                 // Tx enable signal     
        
    .rd_data(rd_data),        // Data read, input
    .rd_rdy_strb(rd_strb_Z2), // Data read ready, input
    .rd_strb(rd_strb),        // Read Register Strobe, output
    .rd_addr(rd_addr),        // Address to read from, output
    .wr_addr(wr_addr),        // Address to write to, output
    .wr_strb(wr_strb),        // Write Register Strobe, output
    .wr_data(wr_data),        // Data to write, output    
    .error(comm_err)          // Error in Com, output
  );   
    
  //COM Route Through Switch
  assign sw_route_thru = (reg_rd_00[12] == 1'b1 && reg_rd_00[3:0] == 4'h4)||(reg_rd_00[13] && reg_rd_00[3:0] != 4'h4) ? 1'b1 : 1'b0;
          
	//---------------------------------------------------------------	
  // PASS THROUGH MODE  
  //---------------------------------------------------------------
  CommModeRouteThru CommModeRouteThru_i1
  (
    .clk(clk),                  // System Clock
    .reset(reset),              // System Reset (Syncronous) 
    .sw_mode(sw_route_thru),    // Flag to indicate switch 1<->2 to 1<->3
    .bus1_rx(TEST1_RX),         // TEST RX FROM PC
    .bus1_tx(TEST1_TX),         // TEST TX TO PC
    .bus2_rx(COM_test_tx),      // internal UART - Registers
    .bus2_tx(COM_test_rx),      // internal UART - Registers
    .bus3_rx(DWNLINK_RX_X_TX),  // from DEVICE to COM
    .bus3_tx(X_sw1_tx)          // from COM to DEVICE
  );    

  CommModeRouteThru CommModeRouteThru_i2
  (
    .clk(clk),                  // System Clock
    .reset(reset),              // System Reset (Syncronous) 
    .sw_mode(sw_route_thru),    // Flag to indicate switch 1<->2 to 1<->3
    .bus1_rx(UPLINK_RX),        // UPLINK_RX FROM LVDS
    .bus1_tx(UPLINK_TX),        // UPLINK_TX TO LVDS
    .bus2_rx(DWNLINK_RX_X_TX),  // internal UART - Registers
    .bus2_tx(X_sw2_tx),         // internal UART - Registers
    .bus3_rx(1'b1),             // from DEVICE to COM
    .bus3_tx()                  // from COM to DEVICE
  );

  //
  always@(posedge clk)
  begin
    if (reset) 
      DWNLINK_TX_X_RX <= 1'b1;
    else
      DWNLINK_TX_X_RX <= X_sw1_tx & X_sw2_tx; 
  end
 	//---------------------------------------------------------------	
	// END PASS THROUGH SWITCH
  	//---------------------------------------------------------------  
  
  
  //---------------------------------------------------------------
  // READ WRITE REGISTERS    
  
  // Write Resgisters
  //Write register 00 from test COM
  always@(posedge clk)
  begin
    if (reset) 
      reg_wr_00 <= {36{1'b0}};
    else if (wr_strb && wr_addr == 4'h0)
      reg_wr_00 <= wr_data;
  end							     
  
  //Write register 01 from test COM	 
  // First bit equals one puts the output JTAG lines in tri-state.
  always@(posedge clk)
  begin
    if (reset) 
      reg_wr_01 <= {36{1'b0}};
    else if (wr_strb && wr_addr == 4'h1)
      reg_wr_01 <= wr_data;
  end			     			     
  
  //Write register 02 from test COM	  
  // First bit equals one indicates reset of ACE Player serial transfer.
  always@(posedge clk)
  begin
    if (reset) 
      reg_wr_02 <= {36{1'b0}};
    else if (wr_strb && wr_addr == 4'h2)
      reg_wr_02 <= wr_data;
  end			     			     
  
  //Write register 03 from test COM	  
  // First bit equals one indicates clear of FIFO.
  always@(posedge clk)
  begin
    if (reset) 
      reg_wr_03 <= {36{1'b0}};
    else if (wr_strb && wr_addr == 4'h3)
      reg_wr_03 <= wr_data;
  end	
  
  //Write register 04 from test COM	 
  // wr_data coming in from serial interface.
  always@(posedge clk)
  begin
    if (reset) 
      reg_wr_04 <= {36{1'b0}};
    else if (wr_strb && wr_addr == 4'h4)
      reg_wr_04 <= wr_data;
  end
  // End of Write Registers

   // Start of Read registers
  //Capture inputs into read registers
  always@(posedge clk)
  begin
    if (reset) begin
      reg_rd_00         <= {36{1'b0}};
    end else begin
      reg_rd_00[0]      <= BRD_TYPE_0;
      reg_rd_00[1]      <= BRD_TYPE_1;
      reg_rd_00[2]      <= BRD_TYPE_2;
      reg_rd_00[3]      <= BRD_TYPE_3;
      reg_rd_00[4]      <= BRD_REV_0;
      reg_rd_00[5]      <= BRD_REV_1;
      reg_rd_00[6]      <= BRD_REV_2;
      reg_rd_00[7]      <= BRD_REV_3;
      reg_rd_00[8]      <= BRD_PARITY;
      reg_rd_00[9]      <= 1'b0;
      reg_rd_00[10]     <= comm_err[0];
      reg_rd_00[11]     <= comm_err[1];
      reg_rd_00[12]     <= X_READY;
      reg_rd_00[13]     <= X_DISCRETE1;
      reg_rd_00[14]     <= X_DISCRETE2;
      reg_rd_00[15]     <= 1'b0;
      reg_rd_00[32:16]  <= reg_wr_00[15:0];
      reg_rd_00[33]     <= 1'b0;
      reg_rd_00[34]     <= JTAG_X_TDO;
      reg_rd_00[35]     <= JTAG_X_DETECT_N;
    end
  end   
  
  //Version Register
  always@(posedge clk)
  begin
    if (reset) begin
      reg_rd_01[35:0]   <= {36{1'b0}};
    end else begin
      reg_rd_01[35:16]  <= {20'h00000};
      reg_rd_01[15:0]   <= X_FPGA_VERSION;
    end
  end   
  
  // Register 2 to read for status of fifo and Ace Player.
  always@(posedge clk)
  begin
    if (reset) begin
      reg_rd_02[35:0]	<= {36{1'b0}};
    end else begin
      reg_rd_02[0]    <= fifo_empty;
      reg_rd_02[1]   	<= fifo_full; 
      reg_rd_02[2]   	<= fifo_half;
      reg_rd_02[3]   	<= error;
      reg_rd_02[4]   	<= eof_done;
    end
  end
  ////////   End of input captures //////////////////////
  
  // Select read data
  always@(rd_addr[1:0],reg_rd_00,reg_rd_01,reg_rd_02)
  begin
    case (rd_addr[1:0])
      2'b00    : rd_data = reg_rd_00;
      2'b01    : rd_data = reg_rd_01;
      2'b10    : rd_data = reg_rd_02;
      default 	: rd_data = reg_rd_00;
    endcase
  end
  
  //Delay rd strobe by 1
  always@(posedge clk)
  begin
    if (reset) begin
      rd_strb_Z1 <= 1'b0;  
      rd_strb_Z2 <= 1'b0;  
    end else begin
      rd_strb_Z1 <= rd_strb;
      rd_strb_Z2 <= rd_strb_Z1;
    end
  end
  
  // END READ IO
  //--------------------------------------------------------------- 


  //---------------------------------------------------------------
  // 250ms Strobe 
    defparam Strobe250ms_i.dw = 24;
    defparam Strobe250ms_i.max = 24'hBEBC20;               
  //---------------------------------------------------------------
  Counter Strobe250ms_i
  (
    .clk(clk),            // Clock input 50 MHz 
    .reset(reset),        // GSR
    .enable(1'b1),        // Enable Counter
    .cntr(),              // Counter value
    .strb(strb_250ms)     // 1 Clk Strb when Counter == max 250 ms
  );   

  
  //---------------------------------------------------------------
  // Shift Register to flag reset power up logic
  always @(posedge clk)
  begin
    if (reset)
      start_seq_shift_reg 			<= 16'b0001;
    else if (start_seq_shift_reg[15] == 1'b0 && strb_250ms == 1'b1)
      start_seq_shift_reg[15:1] 	<= start_seq_shift_reg[14:0];
  end
  //---------------------------------------------------------------

  //Hold logic reset low for (n)*250ms then release
  always @(posedge clk)
  begin
    if (reset)
      endpoint_config_n <= 1'b0;    
    else if (start_seq_shift_reg[12] == 1'b1)
      endpoint_config_n <= 1'b1;
  end
 
  // Write to hold Prog-B low or tri-state to release it.
  assign CONFIG_TARGET = (endpoint_config_n & ~reg_wr_00[1]) ? 1'bZ : 1'b0;

  //Hold logic reset low for (n + m)*250ms then release
  always @(posedge clk)
  begin
    if (reset)
      endpoint_logic_reset_n <= 1'b0;    
    else if (start_seq_shift_reg[14] == 1'b1)
      endpoint_logic_reset_n <= 1'b1;
  end

  assign  X_LOGIC_RESET_N  = endpoint_logic_reset_n & ~reg_wr_00[0]; 

  	// Temporarily Tri-State Signals to not interfere
  	//	assign  JTAG_X_TMS  = 1'bZ; 
	// assign  JTAG_X_TDI  = 1'bZ;
	// assign  JTAG_X_TCK  = 1'bZ;

	// Create delays		 
  	always@(posedge clk)
  	begin
    	if (reset) begin		    		 
    		wr_strb_z1				  <= 1'b0;  		 
    		wr_strb_z2				  <= 1'b0;  		 
    		wr_strb_z3				  <= 1'b0;  		 
    		wr_strb_z4				  <= 1'b0;  		 
    		wr_strb_z5				  <= 1'b0;  		 
    		wr_strb_z6				  <= 1'b0;  		 
    		wr_strb_z7				  <= 1'b0;  		 
    		wr_strb_z8				  <= 1'b0;  		 
    		wr_strb_z9				  <= 1'b0;  		 
    		rdy_z1					    <= 1'b0;  		 
    		rdy_z2					    <= 1'b0;  		 
    		rdy_z3					    <= 1'b0;  		 
    		rdy_z4					    <= 1'b0;  		 
    		rdy_z5					    <= 1'b0;  		 
    		rdy_z6					    <= 1'b0;  		 
    		rdy_z7					    <= 1'b0;  		 
    		rd_ram_strb_z1			<= 1'b0;  		 
    		rd_ram_strb_z2			<= 1'b0;  		 
    		rd_ram_strb_z3			<= 1'b0;  		 
    		rd_ram_strb_z4			<= 1'b0;	  	 		 
    		//COM_LOGICRESET_N_z1	<= 1'b0;	 
    		fifo_empty_z1			  <= 1'b0;	 
    		fifo_empty_z2			  <= 1'b0;	 
    		fifo_empty_z3			  <= 1'b0;	 
    		fifo_empty_z4			  <= 1'b0;	 
    		fifo_empty_z5			  <= 1'b0;	 
    		fifo_empty_z6			  <= 1'b0;		
    		almost_empty_z1		  <= 1'b0;
    	end 
	  	else begin						 					 
    		wr_strb_z1				  <= wr_strb;  					 
    		wr_strb_z2				  <= wr_strb_z1; 					 
    		wr_strb_z3				  <= wr_strb_z2; 					 
    		wr_strb_z4				  <= wr_strb_z3; 					 
    		wr_strb_z5				  <= wr_strb_z4;  					 
    		wr_strb_z6				  <= wr_strb_z5; 					 
    		wr_strb_z7				  <= wr_strb_z6; 					 
    		wr_strb_z8				  <= wr_strb_z7; 					 
    		wr_strb_z9				  <= wr_strb_z8;					 
    		rdy_z1					    <= rdy; 		  					 
    		rdy_z2					    <= rdy_z1;	  					 
    		rdy_z3					    <= rdy_z2;	  					 
    		rdy_z4					    <= rdy_z3;	  					 
    		rdy_z5					    <= rdy_z4;	  					 
    		rdy_z6					    <= rdy_z5;	  					 
    		rdy_z7					    <= rdy_z6;	 		 
    		rd_ram_strb_z1			<= rd_ram_strb;  		 
    		rd_ram_strb_z2			<= rd_ram_strb_z1;	 
    		rd_ram_strb_z3			<= rd_ram_strb_z2;	 
    		rd_ram_strb_z4			<= rd_ram_strb_z3;			 
    		//COM_LOGICRESET_N_z1	<= COM_LOGICRESET_N;	 
    		fifo_empty_z1			  <= fifo_empty;		  	 
    		fifo_empty_z2			  <= fifo_empty_z1;	  	 
    		fifo_empty_z3			  <= fifo_empty_z2;	 		 
    		fifo_empty_z4			  <= fifo_empty_z3;		  	 
    		fifo_empty_z5			  <= fifo_empty_z4;	  	 
    		fifo_empty_z6			  <= fifo_empty_z5; 
    		almost_empty_z1		  <= almost_empty;
    	end
  	end
	///////////////////////////////////////////
	
  	// Determine if the fifo is almost empty.
  	always @(posedge clk)
  	begin
    	if (reset)
      	almost_empty <= 1'b0;    
    	else if ((rdy && !rdy_z1) && (addr_a == addr_b) && !fifo_empty)
      	almost_empty <= 1'b1;    		  // falling edge
    	else if (rdy && almost_empty && (!wr_strb_z8 && wr_strb_z9))
      	almost_empty <= 1'b0;    
    	else
      	almost_empty <= almost_empty;
  	end
	
   always @(posedge clk)
   begin
      if (reset) 							  
         rd_ram_strb <= 1'b0; 
			// rising edge of rdy, fifo not empty and addr_a not equal to addr_b.
	   else if ((rdy && !rdy_z1) && !fifo_empty && (addr_a != addr_b))
         rd_ram_strb <= 1'b1; 
			// rdy and no longer empty.
	   else if (rdy && (!fifo_empty_z5 && fifo_empty_z6))
         rd_ram_strb <= 1'b1; 					
			// rdy and no longer almost empty.
	   else if (rdy && (!almost_empty && almost_empty_z1))
         rd_ram_strb <= 1'b1; 	
      else 
         rd_ram_strb <= 1'b0;
   end 											
	
//   always @(posedge clk)
//   begin
//      if (reset) 
//         strt_ace_clk_strb <= 1'b0; 
//	   else if (COM_LOGICRESET_N && !COM_LOGICRESET_N_z1)
//         strt_ace_clk_strb <= 1'b1;
//      else 
//         strt_ace_clk_strb <= 1'b0;
//   end

	always @(posedge clk)
	   begin
	      if (reset) 
	         load <= 1'b0; 
		   // load after we strobe for a new address with delays.
		   else if (rd_ram_strb_z2 && !rd_ram_strb_z3)
	         load <= 1'b1;
	      else 
	         load <= 1'b0;
	   end   	  
   
	// We'll stretch the load_ace strobe until done_ld_ace
	// is strobed.  
	always @(posedge clk)
   begin
      if (reset) 
         load_ace <= 1'b0; 
	   else if (load)
         load_ace <= 1'b1;
	   else if (done_ld_ace)
         load_ace <= 1'b0;
      else 
         load_ace	<= load_ace;
   end	
	
	// We need to stretch the load strobe longer	 
	// because the ace player is much slower
	// than the system clock.
  	defparam SixtyClksCntr.dw 	= 8;
  	defparam SixtyClksCntr.max	= 8'h3C; // from 1 to 60, could be less
	CounterSeq SixtyClksCntr 
	(	.clk(clk),
		.reset(reset),
		.enable(1'b1),
		.start_strb(load),
		.cntr(),
		.strb(done_ld_ace)
	);
  
  	// Need to parse out the four bytes of data coming into the FIFO.
  	always@(posedge clk)
  	begin
    	if (reset) 
      	datain_b			<= {8{1'b0}};
	  	else if (wr_strb_z1)						
      	datain_b			<= reg_wr_04[31:24];
	  	else if (wr_strb_z3) 						
      	datain_b			<= reg_wr_04[23:16];				  
	  	else if (wr_strb_z5) 						
      	datain_b			<= reg_wr_04[15:8];					
	  	else if (wr_strb_z7) 						
      	datain_b			<= reg_wr_04[7:0];	
	  	else 						
      	datain_b			<= datain_b;
  	end
	  
	// If the fifo is full, the serial interface needs to
	// stop sending.  We don't have any control in here.	  
   defparam FifoController_i1.WIDTH = RAMWIDTH;
	FifoController FifoController_i1 
	(
		.clk(clk),
		.reset(reset),
		.enable(1'b0),					// not connected internally
		// strobe to generate a read address only.
		// The block ram module will actually pull out the data.	
		// Also, won't generate an address if the fifo is empty.
		.rd_a_strb(rd_ram_strb),	
		// strobe to generate a write address only.
		// The block ram module will actually write to the ram.
		.wr_b_strb((wr_strb_z1 || wr_strb_z3 || wr_strb_z5 || wr_strb_z7) && !fifo_full),		
		.addr_a(addr_a),				// read ram addr
		.addr_b(addr_b),				// write ram addr
		.fifo_empty(fifo_empty),
		.fifo_full(fifo_full),
		.fifo_half(fifo_half)
	);					 
	  
	defparam BlockRAM_DPM_1K_x_8_i1.BRAM_INITIAL_FILE = 
	"C:/FPGA_Design/PAKCOMController/src/BRAM_1K_x_8.txt";
	BlockRAM_DPM_1K_x_8 BlockRAM_DPM_1K_x_8_i1 
	(	
		.clk(clk),
		.addr_a(addr_a),			// for read
		.datain_a(),	
		.wr_a(1'b0),
		.addr_b(addr_b),			// for writing
		.datain_b(datain_b),		// write data from serial interface, reg_wr_04			
		// strobe to write, one clock later from wr_b_strb above
		// this is when the data will be available.											
		// Do not write to ram if fifo is full.
		.wr_b((wr_strb_z2 || wr_strb_z4 || wr_strb_z6 || wr_strb_z8) && !fifo_full),		
		.dataout_a(dataout_a),	// read data from addr_a
		.dataout_b()	
	);
   

  // ACE JTAG PROGRAMMER
  AcePlayer AcePlayer_i1 
	(
    // System Control Signals
    .clk(clk),            // Input 1MHz Clock  clk_ace
		.rst(reset),  				// System Reset					
		.load(load_ace),      // Control Load Data Signal
		.data(dataout_a),     // Data to load
    
    // Ace Player Signals
    .tdo(JTAG_X_TDO),     // Input JTAG TDO from target device
		.tms(JTAG_X_TMS_ace), // Output TMS to target device
		.tck(JTAG_X_TCK_ace), // Output TCK to target device
		.tdi(JTAG_X_TDI_ace), // Output TDI to target device
    
    .prog_cntr(),         // Output program counter
		.rdy(rdy),            // Output ready for next data
		.error(error),        // Output error signal
		.eof_done(eof_done)   // Output end of JTAG player file
	);
  
endmodule
  
  