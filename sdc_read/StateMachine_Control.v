//------------------------------------------------------------------------------------------//
//  Module:     StateMachine_Control
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//-----------------------------------------------------------------------------------------//
  
module StateMachine_Control
#( parameter LS = 36)
(  
  input                 clk,                  // System Clock 
  input                 reset,                // System Reset (Syncronous) 
  input                 enable,               // System enable 
  input                 sys_tmr_strb,         // System Timer Strobe  
  
  input [35:0]          monitor_enables,       // Enable monitors
  input [35:0]          monitor_mask,          // Mask monitors
  input [35:0]          cmd_enables,           // Enable Commands
  
  input                 seq_list_done_strb,   // Strobe that sequence list is done
  output reg [LS-1:0]   seq_list_en,          // Flags to enable sequences    
  output reg [15:0]     state_debug           // Register to help test state machine
);

  // STATES
  localparam S00_RESET               = 6'h00;
  localparam S01_POR                 = 6'h01;
  localparam S02_INIT_BRD            = 6'h02;
  localparam S03_INIT_SYS            = 6'h03;
  localparam S04_BOOT_TIME           = 6'h04;
  localparam S05_CMD_RDY             = 6'h05;

  
  reg           por_start_strb;
  reg           por_cnt_en;
  reg           delay8_done;
  reg           boot_start_strb;
  reg           boot_cnt_en;
  reg           delay6_done;
    
  reg           seq_set_initialize;
  wire          seq_srv_initialize;   
      
  reg           seq_en_initialize;
  reg           seq_en_csdl_parsing;
  reg           seq_en_subcom_parsing;
  reg           seq_en_motor_controllers;
  reg           seq_en_claws;
  
  reg [5:0]     current_state;
  reg [5:0]     last_state;
  reg [5:0]     last_state_Z1;
  reg [5:0]     next_state;  
  reg           change_strb;
  
  reg           sys_tmr_strb_Z1;
  reg           sys_tmr_strb_Z2;
  reg           sys_tmr_strb_Z3;
  
  wire          por_cnt_strb;
  wire          boot_cnt_strb;
  
  wire [LS-1:0] seq_list_bits;
  
  initial
  begin   
    por_start_strb            <= 1'b0;
    por_cnt_en                <= 1'b0;
    delay8_done               <= 1'b0;
    boot_start_strb           <= 1'b0;
    boot_cnt_en               <= 1'b0;
    delay6_done               <= 1'b0;    
       
    seq_en_initialize         <= 1'b0;    
    seq_set_initialize        <= 1'b0;
    seq_en_csdl_parsing       <= 1'b0;
    seq_en_subcom_parsing     <= 1'b0;
    seq_en_motor_controllers  <= 1'b0;
    seq_en_claws              <= 1'b0;
    
    sys_tmr_strb_Z1           <= 1'b0;
    sys_tmr_strb_Z2           <= 1'b0;
    sys_tmr_strb_Z3           <= 1'b0;
    change_strb               <= 1'b0;
    current_state             <= 5'h00;
    last_state                <= 5'h00;
    last_state_Z1             <= 5'h00;
    next_state                <= 5'h00;
    seq_list_en               <= {LS{1'b0}};
    
    state_debug               <= 16'h0000;
  end  
        
  // 0 RESET
  // 1 POR
  //    WAIT FOR 16 FRAMES
  // 2 INITIALIZE BOARD
  //    INITIALIZE MOTOR SCRIPTS
  // 3 INITIALIZE SYSTEM
  //    OPEN DOOR
  // 4 BOOT SYSTEM
  //    WAIT FOR 32 FRAMES
  // 5 COMMAND READY  
    
    
  // Delay system timer strobes
  always@(posedge clk)
  begin
    if (reset) begin
      sys_tmr_strb_Z1 <= 1'b0;
      sys_tmr_strb_Z2 <= 1'b0;
      sys_tmr_strb_Z3 <= 1'b0;
    end else begin
      sys_tmr_strb_Z1 <= sys_tmr_strb;
      sys_tmr_strb_Z2 <= sys_tmr_strb_Z1;
      sys_tmr_strb_Z3 <= sys_tmr_strb_Z2;
    end
  end
    
  //Syncronous state from system timer strobe
  always@(posedge clk)
  begin
    if (reset)
        current_state <= S00_RESET;
    else if (sys_tmr_strb)
        current_state <= next_state;
  end  
  
  //State transitions
  always@(current_state, delay8_done, delay6_done)
  begin
    case (current_state)
      S00_RESET             :     next_state <= S01_POR;
      
      S01_POR               :   if (delay8_done)
                                  next_state <= S02_INIT_BRD;
                                else
                                  next_state <= S01_POR;
      
      S02_INIT_BRD          :     next_state <= S03_INIT_SYS;
      
      S03_INIT_SYS          :     next_state <= S04_BOOT_TIME;
      
      S04_BOOT_TIME         :   if (delay6_done)
                                  next_state <= S05_CMD_RDY;
                                else
                                  next_state <= S04_BOOT_TIME;
      
      S05_CMD_RDY           :     next_state <= S05_CMD_RDY;
                                    
      default               :     next_state <= S01_POR;
    endcase
  end
   

  //Syncronous state
  always@(posedge clk)
  begin
    if (reset) begin
        last_state    <= S00_RESET;
        last_state_Z1 <= S00_RESET;
    end else begin
        last_state    <= current_state;
        last_state_Z1 <= last_state;
    end
  end  

  //State change strobe
  always@(posedge clk)
  begin
    if (reset)
      change_strb <= 1'b0;
    else if (last_state_Z1 != last_state)
      change_strb <= 1'b1;
    else
      change_strb <= 1'b0;
  end

//-----------------------------------------------------------------------------------------//
//------------- POR COUNTER  --------------------------------------------------------------//

  //POR Count Start Strb
  always@(posedge clk)
  begin
    if (reset)
      por_start_strb <= 1'b0;
    else if (current_state == S01_POR && change_strb)
      por_start_strb <= 1'b1;
    else
      por_start_strb <= 1'b0;
  end

  //POR Count Enable
  always@(posedge clk)
  begin
    if (reset)
      por_cnt_en <= 1'b0;
    else if (current_state == S01_POR && change_strb)
      por_cnt_en <= 1'b1;
  end
  
  //---------------------------------------------------------------
  // Count system timer strobes 
  //
    defparam POR_State_Cntr_i.dw = 3;
    defparam POR_State_Cntr_i.max = 3'h7;
  //---------------------------------------------------------------
  CounterSeq POR_State_Cntr_i
  (
    .clk(clk),
    .reset(reset),
    .enable(por_cnt_en & sys_tmr_strb),
    .start_strb(por_start_strb),
    .cntr(),
    .strb(por_cnt_strb)
  );  

  //POR Count Done
  always@(posedge clk)
  begin
    if (reset)
      delay8_done <= 1'b0;
    else if (por_cnt_strb)
      delay8_done <= 1'b1;
  end
  
//--------- END POR COUNTER  --------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//-------- INITIALIZE BOARDS---------------------------------------------------------------//    
    
  
  //---- STATE TRANSITION FOR INITIALIAZE -------------------------------------------------//
   
  // Initialize enable  
  always@(posedge clk)
  begin
    if (reset || seq_srv_initialize)
      seq_set_initialize <= 1'b0;
    else if (current_state == S02_INIT_BRD && change_strb)
      seq_set_initialize <= 1'b1;
  end
  
  // Initialize command set
  always@(posedge clk)
  begin
    if (reset || seq_srv_initialize)
      seq_en_initialize <= 1'b0;
    else if (seq_set_initialize && sys_tmr_strb)
      seq_en_initialize <= 1'b1;
  end
    
  // Initialize command serviced
  assign seq_srv_initialize = seq_en_initialize & seq_list_done_strb;
  
  //---- END STATE TRANSITION FOR INITIALIAZE ---------------------------------------------//

  
        
//-------- END INITIALIZE BOARDS-----------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//-------- BOOT COUNTER   -----------------------------------------------------------------// 

  //POR Count Start Strb
  always@(posedge clk)
  begin
    if (reset)
      boot_start_strb <= 1'b0;
    else if (current_state == S04_BOOT_TIME && change_strb)
      boot_start_strb <= 1'b1;
    else
      boot_start_strb <= 1'b0;
  end

  //Boot Count Enable
  always@(posedge clk)
  begin
    if (reset)
      boot_cnt_en <= 1'b0;
    else if (current_state == S04_BOOT_TIME && change_strb)
      boot_cnt_en <= 1'b1;
  end
  
  //---------------------------------------------------------------
  // Count system timer strobes 
  //
    defparam Boot_State_Cntr_i.dw = 3;
    defparam Boot_State_Cntr_i.max = 3'h5;
  //---------------------------------------------------------------
  CounterSeq Boot_State_Cntr_i
  (
    .clk(clk),
    .reset(reset),
    .enable(boot_cnt_en & sys_tmr_strb),
    .start_strb(boot_start_strb),
    .cntr(),
    .strb(boot_cnt_strb)
  );  

  //POR Count Done
  always@(posedge clk)
  begin
    if (reset)
      delay6_done <= 1'b0;
    else if (boot_cnt_strb)
      delay6_done <= 1'b1;
  end
            
//------------- END BOOT COUNTER   --------------------------------------------------------//  
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//------------- CONTINUOUS ENABLES --------------------------------------------------------// 

  // CSDL parsing
  always@(posedge clk)
  begin
    if (reset)
      seq_en_csdl_parsing <= 1'b0;
    else if (current_state == S05_CMD_RDY && sys_tmr_strb_Z3)
      seq_en_csdl_parsing <= 1'b1;
  end    
  
  // Subsystem COMS
  always@(posedge clk)
  begin
    if (reset)
      seq_en_subcom_parsing <= 1'b0;
    else if (current_state == S05_CMD_RDY && sys_tmr_strb_Z3)
      seq_en_subcom_parsing <= 1'b1;
  end     

  // MOTOR CONTROLLERS
  always@(posedge clk)
  begin
    if (reset)
      seq_en_motor_controllers <= 1'b0;
    else if (current_state == S05_CMD_RDY && sys_tmr_strb_Z3)
      seq_en_motor_controllers <= 1'b1;
  end    
  
  // MOTOR CONTROLLERS
  always@(posedge clk)
  begin
    if (reset)
      seq_en_claws <= 1'b0;
    else if (current_state == S05_CMD_RDY && sys_tmr_strb_Z3)
      seq_en_claws <= 1'b1;
  end 
    
//------------- END CONTINUOUS ENABLES ----------------------------------------------------// 
//-----------------------------------------------------------------------------------------//


  // OUTPUT {Syncronized to sys_timer and done strobes} 
  // Create the sequence list enables based on individual sequence enables
  // 
  //   
  assign seq_list_bits[0]   = 1'b0;                                     // 01 Spare
  assign seq_list_bits[1]   = seq_en_initialize;                        // 02 Initialize Enable signals  
  assign seq_list_bits[2]   = 1'b0;                                     // 03 Spare
  assign seq_list_bits[3]   = 1'b0;                                     // 04 Spare
  assign seq_list_bits[4]   = seq_en_csdl_parsing & cmd_enables[0];     // 05 CSDL Parsing
  assign seq_list_bits[5]   = 1'b0;                                     // 06 Spare
  assign seq_list_bits[6]   = seq_en_subcom_parsing & cmd_enables[0];   // 07 Subsystem Communication
  assign seq_list_bits[7]   = seq_en_motor_controllers & cmd_enables[0] & ~monitor_mask[35];// 08 Motor Controller
  assign seq_list_bits[8]   = seq_en_claws & cmd_enables[0];            // 09 Blood Flow Rate Controller
  assign seq_list_bits[9]   = seq_en_claws & cmd_enables[1];            // 10 Dialysate Flow Rate Controller, UF Controller
  assign seq_list_bits[10]  = seq_en_claws & cmd_enables[0];            // 11 IC Flow Rate Controller
  assign seq_list_bits[11]  = seq_en_claws & cmd_enables[0];            // 12 HEP Flow Rate Controller
  assign seq_list_bits[12]  = 1'b0;                                     // 13 Spare
  assign seq_list_bits[13]  = 1'b0;                                     // 14 Spare
  assign seq_list_bits[14]  = 1'b0;                                     // 15 Spare
  assign seq_list_bits[15]  = monitor_enables[35];                      // 16 Clear Monitors
  assign seq_list_bits[16]  = 1'b0;                                     // 17 Spare
  assign seq_list_bits[17]  = 1'b0;                                     // 18 Spare
  assign seq_list_bits[18]  = 1'b0;                                     // 19 Spare
  assign seq_list_bits[19]  = 1'b0;                                     // 20 Spare
  assign seq_list_bits[20]  = monitor_enables[4] & ~monitor_mask[4];    // 21 Enable Control Power System Monitor         Sets Bit 000000100
  assign seq_list_bits[21]  = monitor_enables[5] & ~monitor_mask[5];    // 22 Enable Control Communication System Monitor Sets Bit 000000200
  assign seq_list_bits[22]  = 1'b0;                                     // 23 Spare
  assign seq_list_bits[23]  = 1'b0;                                     // 24 Spare
  assign seq_list_bits[24]  = 1'b0;                                     // 25 Spare
  assign seq_list_bits[25]  = 1'b0;                                     // 26 Spare
  assign seq_list_bits[26]  = 1'b0;                                     // 27 Spare
  assign seq_list_bits[27]  = 1'b0;                                     // 28 Spare
  assign seq_list_bits[28]  = 1'b0;                                     // 29 Spare
  assign seq_list_bits[29]  = 1'b0;                                     // 30 Spare
  assign seq_list_bits[30]  = 1'b0;                                     // 31 Spare
  assign seq_list_bits[31]  = 1'b0;                                     // 32 Spare
  assign seq_list_bits[32]  = 1'b0;                                     // 33 Spare
  assign seq_list_bits[33]  = 1'b0;                                     // 34 Spare
  assign seq_list_bits[34]  = 1'b0;                                     // 35 Spare
  assign seq_list_bits[35]  = 1'b0;                                     // 36 Spare
  
  // Capture enable list for next
  always@(posedge clk)
  begin
    if (reset)
      seq_list_en <= {LS{1'b0}};
    else if (sys_tmr_strb_Z1)
      seq_list_en <= seq_list_bits;
  end
  
  //Debug vector
  always@(posedge clk)
  begin
    if (reset)
      state_debug <= 16'h0000;
    else
      state_debug <= {seq_list_done_strb, sys_tmr_strb, seq_list_en[10:0], current_state[2:0]};  
  end
  
      
endmodule
