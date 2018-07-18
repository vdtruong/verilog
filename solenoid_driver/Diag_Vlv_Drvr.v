//-------------------------------------------------------------------------
// Module:     Diag_Vlv_Drvr.v
// Project:    
// Version:    13
//  Date: 3/20/13
//
// Description: Alternative Implements Driver for Firgelli Solenoids
//  
// We'll use a state machine to implement the solenoid command.
//  We do this by first moving the solenoid(s) to the home
// position then move it to the close or open position.  Close is at the
// surface of the chassis and open is when we close the diaphragm.
// Later on we need to implement a homing command to home all solenoids.
// This version is the same as version 2, except the homing function is
// branched out on a separate path of the state machine.  It homes all
// the plungers and go to idle after it finishes. 2/20/13
// This version is the same as version 7, except now it knows that a 
// previous home all command was used.  In this case, any new command
// bit will be executed by the state machine. 2/26/13
// This version is the same as version 8 but with automatic stop included.
// It uses a separate state machine and a counter. It finds the 
// difference between two values to see if there is any change. 
// If there is a change within 5 adc counts, we know there is no change.
// 2/28/13 
// Changed names from DV1-DV3 to DV0-DV2 to match system diagrams
//-------------------------------------------------------------------------
module Diag_Vlv_Drvr
  #(  // 0.5 sec. timeout to move solenoid  at 50 MHz.
    parameter TIMEOUT_CNTS    = 28'h17D7840,
    // Wait 5 ms before turning on open or close after
    // activating EVP.               at 50 MHz.
    parameter WAIT_CNTS      = 20'h3D090,
    // Wait 50 ms before we compare the current adc count and the
    // previous adc count.
    parameter WAIT_ADC_CNT_CHG  = 24'h2625A0)   
  (  
  input       clk,          // System clk 
  input       reset,        // System Reset
  input  [6:0]  state_cmd,  // Solenoid command [Home,J3,J4,J5,J8,J7,J6]  
  input       strb_load,    // Strobe to start state machine
  
  // This is the homing limit to stop moving the solenoids.
  input [9:0]  DV_home_lim,
  
  // These are opening diaphragm limits to stop moving the solenoids.
  input [9:0]  DV1P1_open_lim, // J3
  input [9:0]  DV1P2_open_lim, // J4
  input [9:0]  DV2P1_open_lim, // J5
  input [9:0]  DV2P2_open_lim, // J6
  input [9:0]  DV3P1_open_lim, // J7
  input [9:0]  DV3P2_open_lim, // J8
  
  // These are closing diaphragm limits to stop moving the solenoids.
  input [9:0]  DV1P1_close_lim, // J3
  input [9:0]  DV1P2_close_lim, // J4
  input [9:0]  DV2P1_close_lim, // J5
  input [9:0]  DV2P2_close_lim, // J6
  input [9:0]  DV3P1_close_lim, // J7
  input [9:0]  DV3P2_close_lim, // J8
  
  // Pull in the solenoids' outputs so we can tell when
  // to stop the solenoids' movements.
  input [9:0]  DV1P1_sense, // J3 
  input [9:0]  DV1P2_sense, // J4
  input [9:0]  DV2P1_sense, // J5
  input [9:0]  DV2P2_sense, // J6
  input [9:0]  DV3P1_sense, // J7
  input [9:0]  DV3P2_sense, // J8
  
  // Outputs to control the solenoids.
  output    reg  DV_OPEN,   // Flag to Open enabled MagValve
  output    reg  DV_CLOSE,  // Flag to Close enabled MagValve
  output    reg  EVP1,     // Enable Valve Plunger 1 - J3
  output    reg  EVP2,     // Enable Valve Plunger 2 - J4
  output    reg  EVP3,     // Enable Valve Plunger 3 - J5
  output    reg  EVP4,     // Enable Valve Plunger 4 - J6
  output    reg  EVP5,     // Enable Valve Plunger 5 - J7
  output    reg  EVP6      // Enable Valve Plunger 6 - J8
);

  // STATES
  localparam  S00 = 5'h00;   // idle
  localparam  S01 = 5'h01;   // Check to see if home all command.
  localparam  S02 = 5'h02;   // Ask if a prev. cmd is an all home cmd.  
  // Search each state_cmd to see if it is different from
  // the previous state_cmd.
  localparam   S03 = 5'h03;  
  localparam   S04 = 5'h04;  // New cmd is 1?
  localparam   S05 = 5'h05;  // Store in no change memory.
  localparam   S06 = 5'h06;  // Put 1 in the open_mem_b[cmd_indx_sl].
  localparam   S07 = 5'h07;  // Store in yes (open) memory.   
  localparam   S08 = 5'h08;  // Put 1 in the close_mem_b[cmd_indx_sl]. 
  localparam   S09 = 5'h09;  // Store in no (close) memory. 
  localparam   S10 = 5'h0a;  // End search? 
  localparam   S11 = 5'h0b;  // Increment cmd_index. 
  localparam   S12 = 5'h0c;  // No change memory full? 
  localparam   S13 = 5'h0d;  // Home all necessary plungers, set EVPs. 
  localparam   S14 = 5'h0e;  // Wait 5 ms 
  localparam   S15 = 5'h0f;  // Switch DV_CLOSE_sig = 1. 
  localparam   S16 = 5'h10;  // Stop individual EVP when done homing. 
  localparam   S17 = 5'h11;  //  Turn off DV_CLOSE_sig. 
  localparam   S18 = 5'h12;  // Wait 5 ms 
  localparam   S19 = 5'h13;  // Set EVPs. 
  localparam   S20 = 5'h14;  // Wait 5 ms 
  localparam   S21 = 5'h15;  // Switch DV_OPEN_sig = 1. 
  localparam   S22 = 5'h16;  // Stop individual EVP when done opening. 
  localparam   S23 = 5'h17;  // Switch DV_OPEN_sig = 0. 
  localparam   S24 = 5'h18;  // Set all EVPs to home all plungers.
  localparam   S25 = 5'h19;  // Wait 5 ms.
  localparam   S26 = 5'h1a;  // Switch DV_CLOSE_sig = 1.
  localparam   S27 = 5'h1b;  // Stop individual EVP when done homing.
  localparam   S28 = 5'h1c;  // Turn off DV_CLOSE_sig.
  
  // STATES for determining adc count change.
  localparam   S00adc = 3'h0;  // idle
  localparam   S01adc = 3'h1;  // Start counter.
  localparam   S02adc = 3'h2;  // Wait to find next adc count.
  localparam   S03adc = 3'h3;  // Find the adc count difference.
  localparam   S04adc = 3'h4;  // Decide whether to start counter again.
  
  // Wires  
  wire  timeout_strb;          // timeout to turn solenoid
  wire  wt_done_strb;          // time up to turn on open or close
  wire  time_up;               // Time up for adc timer.
  
  // Regs.  
  reg  [4:0] current_state;
  reg  [4:0]  next_state;  
  
  reg  [6:0]  last_ste_cmd;   // Keep track of prev_ste_cmd in sequential logic. 
  reg  [6:0]  prev_ste_cmd;   // Save the current state_cmd for next time.
  reg  [2:0]  cmd_indx;       // Index of the state_cmd array.
  reg  [2:0]  cmd_indx_sl;    // For use in sensitivity list.
  reg  [2:0]  no_chg_cnt;     // If this equals 6 we have no change in state_cmd.
  reg  [2:0]  no_chg_cnt_sl;  // For use in sensitivity list.
  reg  [5:0]  open_mem;       // Array of open diaphragm sols. according to state_cmd.
  reg  [5:0]  open_mem_sl;    // For use in sensitivity list.
  reg  [5:0]  open_mem_b;     // Need this to set to 1 in the necessary index.
  reg  [5:0]  open_mem_b_sl;  // For use in sensitivity list.
  reg  [5:0]  close_mem;      // Array of close diaphragm sols. according to state_cmd.
  reg  [5:0]  close_mem_sl;   // For use in sensitivity list.
  reg  [5:0]  close_mem_b;    // Need this to set to 1 in the necessary index.
  reg  [5:0]  close_mem_b_sl; // For use in sensitivity list.
  reg  [5:0]  merge_mem;      // Merge array of open_mem and close_mem arrays.
  reg   [9:0] stop_lim_0;     // Need six stop limits for six EVPs.  This changes 
                              // according to either moving to the surface or beyond.
  reg   [9:0] stop_lim_1;
  reg   [9:0] stop_lim_2;
  reg   [9:0] stop_lim_3;
  reg   [9:0] stop_lim_4;
  reg   [9:0] stop_lim_5;                    
  reg      mov_cntr_strb;     // time limit for moving solenoid
  reg      wt_cntr_strb;      // wait for 5 ms starting strobe
  reg      finish_home;       // finish closing solenoid(s), pulling back
  reg      finish_move;       // finish opening solenoid(s), pushing out
  reg      no_cmd_chg;        // There is no change between the new state_cmd
                              // and the previous state_cmd.
  reg      end_search;        // We have gone through all the state_cmd elements.
  reg      cmd_diff;          // Compare to see if the current state_cmd and the 
                              // previous state_cmd are different.
  reg      open_cmd;          // Command is an open solenoid command if it is 1.
                              // Remember if the last command was a home all command.
  reg      just_home;
  reg      just_home_sl;
  
  // Below are for monitorning adc change.
  reg   [2:0] cur_ste;        // For determining adc change.
  reg   [2:0] nxt_ste;        // For determining adc change.
  
  reg   [9:0] cur_adc_P1;     // Place holder to be set as previous adc.
  reg   [9:0] cur_adc_P2;    
  reg   [9:0] cur_adc_P3;    
  reg   [9:0] cur_adc_P4;    
  reg   [9:0] cur_adc_P5;    
  reg   [9:0] cur_adc_P6;    
  reg   [9:0] cur_adc_P1_sl;  // Used in sensitivity list.
  reg   [9:0] cur_adc_P2_sl;    
  reg   [9:0] cur_adc_P3_sl;    
  reg   [9:0] cur_adc_P4_sl;    
  reg   [9:0] cur_adc_P5_sl;    
  reg   [9:0] cur_adc_P6_sl;    
  reg   [9:0] adc_diff_1;     // adc P1 diff.
  reg   [9:0] adc_diff_2;     // 
  reg   [9:0] adc_diff_3;     // 
  reg   [9:0] adc_diff_4;     // 
  reg   [9:0] adc_diff_5;     // 
  reg   [9:0] adc_diff_6;     // 
  reg   [9:0] adc_diff_1_sl;  // For sensitivity list.
  reg   [9:0] adc_diff_2_sl;  // For sensitivity list.
  reg   [9:0] adc_diff_3_sl;  // For sensitivity list.
  reg   [9:0] adc_diff_4_sl;  // For sensitivity list.
  reg   [9:0] adc_diff_5_sl;  // For sensitivity list.
  reg   [9:0] adc_diff_6_sl;  // For sensitivity list. 
          // Stop motor if adc change value is within 5 counts.
  reg      stop_motor_P1;  
  reg      stop_motor_P2;
  reg      stop_motor_P3;
  reg      stop_motor_P4;
  reg      stop_motor_P5;
  reg      stop_motor_P6;          
  
  reg DV_OPEN_sig;
  reg DV_CLOSE_sig;
  reg EVP1_sig;
  reg EVP2_sig;
  reg EVP3_sig;
  reg EVP4_sig;
  reg EVP5_sig;
  reg EVP6_sig;  
  
  reg [9:0] DV1P1_below_open_lim;
  reg [9:0] DV1P2_below_open_lim;
  reg [9:0] DV2P1_below_open_lim;
  reg [9:0] DV2P2_below_open_lim;
  reg [9:0] DV3P1_below_open_lim;
  reg [9:0] DV3P2_below_open_lim;
  
  reg      strt_adc_mon;  // Start to monitor adc change going out.
                          // Start timer to find next adc count.
  reg      strt_cntr;    
  
  // Initialize sequential logic
  initial      
  begin     
    current_state         <= 5'h00;
    next_state            <= 5'h00;
    
    last_ste_cmd          <= 7'h00;
    prev_ste_cmd          <= 7'h00;
    cmd_indx              <= 3'h0;
    cmd_indx_sl           <= 3'h0;
    no_chg_cnt            <= 3'h0;
    no_chg_cnt_sl         <= 3'h0;
    open_mem              <= 6'h00;
    open_mem_sl           <= 6'h00;
    open_mem_b            <= 6'h00;
    open_mem_b_sl         <= 6'h00;
    close_mem             <= 6'h00;
    close_mem_sl          <= 6'h00;
    close_mem_b           <= 6'h00;
    close_mem_b_sl        <= 6'h00;
    merge_mem             <= 6'h00;
    
    stop_lim_0            <= 10'h000;
    stop_lim_1            <= 10'h000;
    stop_lim_2            <= 10'h000;
    stop_lim_3            <= 10'h000;
    stop_lim_4            <= 10'h000;
    stop_lim_5            <= 10'h000;
    
    DV1P1_below_open_lim  <= 10'h000;
    DV1P2_below_open_lim  <= 10'h000;
    DV2P1_below_open_lim  <= 10'h000;
    DV2P2_below_open_lim  <= 10'h000;
    DV3P1_below_open_lim  <= 10'h000;
    DV3P2_below_open_lim  <= 10'h000;

    DV_OPEN_sig           <= 1'b0;
    DV_CLOSE_sig          <= 1'b0;    
    EVP1_sig             <= 1'b0;
    EVP2_sig             <= 1'b0;
    EVP3_sig             <= 1'b0;
    EVP4_sig             <= 1'b0;
    EVP5_sig             <= 1'b0;
    EVP6_sig             <= 1'b0;
    
    DV_OPEN               <= 1'b0;
    DV_CLOSE              <= 1'b0;    
    EVP1                 <= 1'b0;
    EVP2                 <= 1'b0;
    EVP3                 <= 1'b0;
    EVP4                 <= 1'b0;
    EVP5                 <= 1'b0;
    EVP6                 <= 1'b0;
    
    mov_cntr_strb         <= 1'b0;
    wt_cntr_strb          <= 1'b0;
    finish_home           <= 1'b0;
    finish_move           <= 1'b0;
    no_cmd_chg            <= 1'b0;
    end_search            <= 1'b0;
    cmd_diff              <= 1'b0;
    just_home             <= 1'b0;
    just_home_sl          <= 1'b0;
    
    // For monitoring adc difference.
    cur_ste               <= 3'h0;
    nxt_ste               <= 3'h0;
    
    cur_adc_P1            <= 10'h000;
    cur_adc_P2            <= 10'h000;
    cur_adc_P3            <= 10'h000;
    cur_adc_P4            <= 10'h000;
    cur_adc_P5            <= 10'h000;
    cur_adc_P6            <= 10'h000;      
    cur_adc_P1_sl         <= 10'h000;
    cur_adc_P2_sl         <= 10'h000;
    cur_adc_P3_sl         <= 10'h000;
    cur_adc_P4_sl         <= 10'h000;
    cur_adc_P5_sl         <= 10'h000;
    cur_adc_P6_sl         <= 10'h000;      
    adc_diff_1            <= 10'h000;
    adc_diff_2            <= 10'h000;
    adc_diff_3            <= 10'h000;
    adc_diff_4            <= 10'h000;
    adc_diff_5            <= 10'h000;
    adc_diff_6            <= 10'h000;      
    adc_diff_1_sl         <= 10'h000;
    adc_diff_2_sl         <= 10'h000;
    adc_diff_3_sl         <= 10'h000;
    adc_diff_4_sl         <= 10'h000;
    adc_diff_5_sl         <= 10'h000;
    adc_diff_6_sl         <= 10'h000;
    
    stop_motor_P1         <= 1'b0;
    stop_motor_P2         <= 1'b0;
    stop_motor_P3         <= 1'b0;
    stop_motor_P4         <= 1'b0;
    stop_motor_P5         <= 1'b0;
    stop_motor_P6         <= 1'b0;
    strt_adc_mon          <= 1'b0;
    strt_cntr             <= 1'b0;
  end  
  
  //Synchronous (sequential) state.
  always@(posedge clk)
  begin
    if (reset)
      current_state <= S00;
    else
      current_state <= next_state;
  end  
  
  //State transitions (combinational).
  always@(current_state, strb_load, state_cmd, last_ste_cmd, wt_done_strb, 
        timeout_strb, finish_home, finish_move, DV_home_lim, stop_lim_0,
        stop_lim_1, stop_lim_2, stop_lim_3, stop_lim_4, stop_lim_5,
        DV1P1_below_open_lim,DV1P2_below_open_lim,DV2P1_below_open_lim,
        DV2P2_below_open_lim,DV3P1_below_open_lim,DV3P2_below_open_lim,
        DV1P1_sense, DV1P2_sense, DV2P1_sense, DV2P2_sense, DV3P1_sense, 
        DV3P2_sense, end_search, open_cmd, no_chg_cnt_sl, open_mem_sl,
        open_mem_b_sl, close_mem_sl, close_mem_b_sl, cmd_indx_sl, cmd_diff,
        merge_mem, no_cmd_chg, just_home_sl, stop_motor_P1,
        stop_motor_P2, stop_motor_P3, stop_motor_P4,
        stop_motor_P5, stop_motor_P6)
  begin
    // State machine defaults.
    prev_ste_cmd                <= 7'h00;
    cmd_indx                    <= 3'h0;
    no_chg_cnt                  <= 3'h0;
    open_mem                    <= 6'h00;
    open_mem_b                  <= 6'h00;
    close_mem                   <= 6'h00;
    close_mem_b                 <= 6'h00;
          
    just_home                   <= 1'b0;
          
    mov_cntr_strb               <= 1'b0;
    wt_cntr_strb                <= 1'b0;
    strt_adc_mon                <= 1'b0;
    
    DV_OPEN_sig                     <= 1'b0;
    DV_CLOSE_sig                    <= 1'b0;    
    EVP1_sig                       <= 1'b0;
    EVP2_sig                       <= 1'b0;
    EVP3_sig                       <= 1'b0;
    EVP4_sig                       <= 1'b0;
    EVP5_sig                       <= 1'b0;
    EVP6_sig                       <= 1'b0;
    
    next_state                  <= current_state;
    case (current_state)
      S00:  // Idle state
        begin          
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 3'h0;
          open_mem              <= 6'h00;
          open_mem_b            <= 6'h00;
          close_mem             <= 6'h00;
          close_mem_b           <= 6'h00;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;        
      
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (strb_load)
            next_state          <= S01;
          else
            next_state          <= S00;
          end
      S01:  // Check to see if home all command.
        begin          
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 3'h0;
          open_mem              <= 6'h00;
          open_mem_b            <= 6'h00;
          close_mem             <= 6'h00;
          close_mem_b           <= 6'h00;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;          
    
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (state_cmd[6] == 1'b1)  // Start to home all solenoids.
            next_state          <= S24; 
          else
            next_state          <= S02;
          end
      S02:  // Ask if a prev. cmd is an all home cmd.
        begin          
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (just_home_sl)  
            next_state          <= S04; 
          else
            next_state          <= S03;
        end
      S03:  // Search each state_cmd to see if it is different from
          // the previous state_cmd.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (cmd_diff)
            next_state          <= S04; // Go to New cmd is 1? state.
          else                          // Go to Store in no change mem.
            next_state          <= S05; 
        end
      S04:  // New cmd is 1?
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
            
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (open_cmd)
            next_state          <= S06; // Go to open_mem_b state
          else
            next_state          <= S08; // Go to close_mem_b state
        end
      S05:  // Store in no change memory.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          // Add one if state_cmd does not change.
          no_chg_cnt            <= no_chg_cnt_sl + 1'b1;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
            
          next_state            <= S10;  // go to end search state
        end
      S06:  // Put 1 in the open_mem_b[cmd_indx_sl].
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b[cmd_indx_sl]    <= 1'b1;  
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          next_state            <= S07; // Go to yes (open) mem state.
        end
      S07:  // Store in yes (open) memory.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl | open_mem_b_sl;
          open_mem_b            <= open_mem_b_sl;    
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          next_state            <= S10;  // Go to End Search? state.
        end
      S08: // Put 1 in the close_mem_b[cmd_indx_sl].
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b[cmd_indx_sl]  <= 1'b1; // Need this for oring.
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
            
          next_state            <= S09; // Go to no (close) mem state
        end
      S09: // Store in no (close) memory.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl |  close_mem_b_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          next_state            <= S10; // Go to End Search? state.
        end
      S10:  // End Search?
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
        
          if (end_search)
            next_state          <= S12; // Go to No change memory full?
          else
            next_state          <= S11; // Go to Increment cmd_indx state.
        end
      S11: // Increment cmd index.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= cmd_indx_sl + 1'b1;
          no_chg_cnt            <= no_chg_cnt_sl;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (just_home_sl)  
            next_state          <= S04; // New cmd is 1?
          else  
            next_state          <= S03; 
        end
      S12:  // No change memory full?
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (no_cmd_chg)
            // Go to idle if no change in command.
            next_state          <= S00;
          else  
            // Go to home all nec. plungers.
            next_state          <= S13; 
          end
      S13:  // Home all necessary plungers, set EVPs.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          // Wait a bit before turning on DV_CLOSE_sig
          wt_cntr_strb          <= 1'b1; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b0;  
          EVP1_sig                 <= merge_mem[5]; // J3
          EVP2_sig                 <= merge_mem[4]; // J4
          EVP3_sig                 <= merge_mem[3]; // J5
          EVP4_sig                 <= merge_mem[0]; // J6
          EVP5_sig                 <= merge_mem[1]; // J7
          EVP6_sig                 <= merge_mem[2]; // J8
          
          next_state            <= S14;
        end
      S14:  // Wait 5 ms
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b0;  
          EVP1_sig                 <= merge_mem[5];
          EVP2_sig                 <= merge_mem[4];
          EVP3_sig                 <= merge_mem[3];
          EVP4_sig                 <= merge_mem[0];
          EVP5_sig                 <= merge_mem[1];
          EVP6_sig                 <= merge_mem[2];
            
          if (wt_done_strb)
            next_state          <= S15;
          else  
            next_state          <= S14;
        end
      S15:  // Switch DV_CLOSE_sig = 1.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b1; // start timeout counter
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b1; // Start motor 
          EVP1_sig                 <= merge_mem[5]; // J3
          EVP2_sig                 <= merge_mem[4]; // J4
          EVP3_sig                 <= merge_mem[3]; // J5
          EVP4_sig                 <= merge_mem[0]; // J6
          EVP5_sig                 <= merge_mem[1]; // J7
          EVP6_sig                 <= merge_mem[2]; // J8
          
          next_state            <= S16;
        end
      S16:  // Stop individual EVP when done homing.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b1;  // Keep motor running
          
          // If it has reached or went under the homing limit or    
          // timeout, stop turning the solenoid.  
          if (((DV1P1_sense <= DV1P1_below_open_lim) | timeout_strb)) 
            EVP1_sig               <= 1'b0; // J3
          else  // Keep as it is, could be 0 or 1.
            EVP1_sig               <= merge_mem[5];
          if (((DV1P2_sense <= DV1P2_below_open_lim) | timeout_strb))
            EVP2_sig               <= 1'b0; // J4
          else
            EVP2_sig               <= merge_mem[4];
          if (((DV2P1_sense <= DV2P1_below_open_lim) | timeout_strb))
            EVP3_sig               <= 1'b0; // J5
          else
            EVP3_sig               <= merge_mem[3];
          if (((DV2P2_sense <= DV2P2_below_open_lim) | timeout_strb)) 
            EVP4_sig               <= 1'b0; // J6
          else
            EVP4_sig               <= merge_mem[0];
          if (((DV3P1_sense <= DV3P1_below_open_lim) | timeout_strb)) 
            EVP5_sig               <= 1'b0; // J7
          else
            EVP5_sig               <= merge_mem[1];
          if (((DV3P2_sense <= DV3P2_below_open_lim) | timeout_strb)) 
            EVP6_sig               <= 1'b0; // J8
          else
            EVP6_sig               <= merge_mem[2];
            
          // When all solenoids are at home or timeout, go to next state.
          if (finish_home |  timeout_strb)
            next_state          <= S17;
               else
            next_state          <= S16;
        end
      S17:  // Turn off DV_CLOSE_sig.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          // Wait 5 ms before turning on EVPs.
          wt_cntr_strb          <= 1'b1; 
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0; // Turn off DV_CLOSE_sig.    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          next_state            <= S18;
        end  
      S18:  // Wait 5 ms
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          if (wt_done_strb)
            next_state          <= S19;
          else  
            next_state          <= S18;
        end
      S19:  // Set EVPs.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          // Wait a bit before turning on DV_OPEN_sig
          wt_cntr_strb          <= 1'b1;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b0;  
          EVP1_sig                 <= merge_mem[5]; // J3
          EVP2_sig                 <= merge_mem[4]; // J4
          EVP3_sig                 <= merge_mem[3]; // J5
          EVP4_sig                 <= merge_mem[0]; // J6
          EVP5_sig                 <= merge_mem[1]; // J7
          EVP6_sig                 <= merge_mem[2]; // J8
          
          next_state            <= S20;
        end
      S20:  // Wait 5 ms
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0;    
          EVP1_sig                 <= merge_mem[5]; // J3
          EVP2_sig                 <= merge_mem[4]; // J4
          EVP3_sig                 <= merge_mem[3]; // J5
          EVP4_sig                 <= merge_mem[0]; // J6
          EVP5_sig                 <= merge_mem[1]; // J7
          EVP6_sig                 <= merge_mem[2]; // J8
            
          if (wt_done_strb)
            next_state          <= S21;
          else  
            next_state          <= S20;
        end
      S21:  // Switch DV_OPEN_sig = 1.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b1; // start timeout counter
          wt_cntr_strb          <= 1'b0;  
          strt_adc_mon          <= 1'b1;
          
          DV_OPEN_sig               <= 1'b1; // Start motor
          DV_CLOSE_sig              <= 1'b0;  
          EVP1_sig                 <= merge_mem[5]; // J3
          EVP2_sig                 <= merge_mem[4]; // J4
          EVP3_sig                 <= merge_mem[3]; // J5
          EVP4_sig                 <= merge_mem[0]; // J6
          EVP5_sig                 <= merge_mem[1]; // J7
          EVP6_sig                 <= merge_mem[2]; // J8
          
          next_state            <= S22;
        end
      S22:  // Stop individual EVP when done opening.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
            
          DV_OPEN_sig               <= 1'b1; // Keep motor running
          DV_CLOSE_sig              <= 1'b0;  
          
          // If it has reached or went over the open diaphragm or close
          // diaphgragm limit or timeout, stop turning the solenoid.
          // Also, stop when it has hit a plate.
          if (((DV1P1_sense >= stop_lim_0) | stop_motor_P1 | timeout_strb)) 
            EVP1_sig <= 1'b0; // J3
          else  // Keep as it is, could be 0 or 1.
            EVP1_sig <= merge_mem[5];
            
          if (((DV1P2_sense >= stop_lim_1) | stop_motor_P2 | timeout_strb))
            EVP2_sig <= 1'b0; // J4
          else
            EVP2_sig <= merge_mem[4];
            
          if (((DV2P1_sense >= stop_lim_2) | stop_motor_P3 | timeout_strb))
            EVP3_sig <= 1'b0; // J5
          else
            EVP3_sig <= merge_mem[3];
            
          if (((DV2P2_sense >= stop_lim_3) | stop_motor_P4 | timeout_strb)) 
            EVP4_sig <= 1'b0; // J6
          else                  
            EVP4_sig <= merge_mem[0];
            
          if (((DV3P1_sense >= stop_lim_4) | stop_motor_P5 | timeout_strb)) 
            EVP5_sig <= 1'b0; // J7
          else
            EVP5_sig <= merge_mem[1];
            
          if (((DV3P2_sense >= stop_lim_5) | stop_motor_P6 | timeout_strb)) 
            EVP6_sig <= 1'b0; // J8
          else
            EVP6_sig <= merge_mem[2];
            
          // When all solenoids are at home or timeout, go to next state.
          if (finish_move |  timeout_strb)
            next_state <= S23;
          else
            next_state <= S22;
          end
      S23:  // Turn off DV_OPEN_sig.
        begin
          prev_ste_cmd          <= state_cmd; // save for next time
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= 1'b0; // Need to turn off just_home.
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; // Turn off DV_OPEN_sig.
          DV_CLOSE_sig              <= 1'b0;     
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          next_state            <= S00;
        end
      S24:  // Home all plungers, set all EVPs.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
            
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b0;
          // Wait a bit before turning on DV_CLOSE_sig
          wt_cntr_strb          <= 1'b1;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b0;  
          EVP1_sig                 <= 1'b1; // J3
          EVP2_sig                 <= 1'b1; // J4
          EVP3_sig                 <= 1'b1; // J5
          EVP4_sig                 <= 1'b1; // J6
          EVP5_sig                 <= 1'b1; // J7
          EVP6_sig                 <= 1'b1; // J8
          
          next_state            <= S25;
        end
      S25:  // Wait 5 ms
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
            
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b0;  
          EVP1_sig                 <= 1'b1; // J3
          EVP2_sig                 <= 1'b1; // J4
          EVP3_sig                 <= 1'b1; // J5
          EVP4_sig                 <= 1'b1; // J6
          EVP5_sig                 <= 1'b1; // J7
          EVP6_sig                 <= 1'b1; // J8
            
          if (wt_done_strb)
            next_state          <= S26;
          else
            next_state          <= S25;
          end                     
        
      S26:  // Switch DV_CLOSE_sig = 1.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
          
          mov_cntr_strb         <= 1'b1; // start timeout counter
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
          
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b1; // Start motor
          EVP1_sig                 <= 1'b1; // J3
          EVP2_sig                 <= 1'b1; // J4
          EVP3_sig                 <= 1'b1; // J5
          EVP4_sig                 <= 1'b1; // J6
          EVP5_sig                 <= 1'b1; // J7
          EVP6_sig                 <= 1'b1; // J8
          
          next_state            <= S27;
        end
      S27:  // Stop individual EVP when done homing.
        begin
          prev_ste_cmd          <= last_ste_cmd;
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= just_home_sl;
            
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
            
          DV_OPEN_sig               <= 1'b0; 
          DV_CLOSE_sig              <= 1'b1;  // Keep motor running
          
          // If it has reached or went under the homing limit or    
          // timeout, stop turning the solenoid. 
          if (((DV1P1_sense <= DV_home_lim) | timeout_strb)) 
            EVP1_sig <= 1'b0; // J3
          else  // Keep 1.
            EVP1_sig <= 1'b1;
            
          if (((DV1P2_sense <= DV_home_lim) | timeout_strb))
            EVP2_sig <= 1'b0; // J4
          else
            EVP2_sig <= 1'b1;
            
          if (((DV2P1_sense <= DV_home_lim) | timeout_strb))
            EVP3_sig <= 1'b0; // J5
          else
            EVP3_sig <= 1'b1;
            
          if (((DV2P2_sense <= DV_home_lim) | timeout_strb)) 
            EVP4_sig <= 1'b0; // J6
          else
            EVP4_sig <= 1'b1;
            
          if (((DV3P1_sense <= DV_home_lim) | timeout_strb)) 
            EVP5_sig <= 1'b0; // J7
          else
            EVP5_sig <= 1'b1;
            
          if (((DV3P2_sense <= DV_home_lim) | timeout_strb)) 
            EVP6_sig <= 1'b0; // J8
          else
            EVP6_sig <= 1'b1;
            
          // When all solenoids are at home or timeout, go to next state.
          if (finish_home |  timeout_strb)
            next_state <= S28;
          else
            next_state <= S27;
          end          
          
      S28:  // Turn off DV_CLOSE_sig.
        begin
          prev_ste_cmd          <= state_cmd; // save for next time
          cmd_indx              <= 3'h0;
          no_chg_cnt            <= 6'h00;
          open_mem              <= open_mem_sl;
          open_mem_b            <= open_mem_b_sl;
          close_mem             <= close_mem_sl;
          close_mem_b           <= close_mem_b_sl;
          
          just_home             <= 1'b1; // Just finished homing all.
          
          mov_cntr_strb         <= 1'b0;
          wt_cntr_strb          <= 1'b0;
          strt_adc_mon          <= 1'b0;
            
          DV_OPEN_sig               <= 1'b0;
          DV_CLOSE_sig              <= 1'b0; // Turn off DV_CLOSE_sig.    
          EVP1_sig                 <= 1'b0;
          EVP2_sig                 <= 1'b0;
          EVP3_sig                 <= 1'b0;
          EVP4_sig                 <= 1'b0;
          EVP5_sig                 <= 1'b0;
          EVP6_sig                 <= 1'b0;
          
          next_state            <= S00;
        end
      default:    
        next_state              <= S00;
    endcase
  end
  // End of state machine.

  // Merge open and close plungers command.
  always@(posedge clk)
  begin
    if (reset)
      merge_mem  <= 6'h00;
    else if (current_state == S10)
      merge_mem  <= open_mem | close_mem;
    else
      merge_mem  <= merge_mem;
  end 

  // Keep track of the previous state_cmd.
  always@(posedge clk)
  begin
    if (reset)
      last_ste_cmd  <= 7'h00;
    else
      last_ste_cmd  <= prev_ste_cmd;
  end 

  // Keep track of cmd_indx.
  always@(posedge clk)
  begin
    if (reset)
      cmd_indx_sl  <= 3'h0;
    else
      cmd_indx_sl  <= cmd_indx;
  end 

  // Keep track of no_chg_cnt.
  always@(posedge clk)
  begin
    if (reset)
      no_chg_cnt_sl  <= 3'h0;
    else
      no_chg_cnt_sl  <= no_chg_cnt;
  end 

  // Sensitivity list item of open_mem.
  always@(posedge clk)
  begin
    if (reset)
      open_mem_sl  <= 6'h00;
    else
      open_mem_sl  <= open_mem;
  end 

  // Sensitivity list item of open_mem_b.
  always@(posedge clk)
  begin
    if (reset)
      open_mem_b_sl  <= 6'h00;
    else
      open_mem_b_sl  <= open_mem_b;
  end 

  // Sensitivity list item of close_mem.
  always@(posedge clk)
  begin
    if (reset)
      close_mem_sl  <= 6'h00;
    else
      close_mem_sl  <= close_mem;
  end 

  // Sensitivity list item of close_mem_b.
  always@(posedge clk)
  begin
    if (reset)
      close_mem_b_sl  <= 6'h00;
    else
      close_mem_b_sl  <= close_mem_b;
  end 

  // Sensitivity list item of just_home.
  always@(posedge clk)
  begin
    if (reset)
      just_home_sl  <= 1'b0;
    else
      just_home_sl  <= just_home;
  end 
  
  // Check to see if we have a change in the new state_cmd.
  // If there is 6 no changes in state_cmd then we have
  // no change in the new state_cmd.  If this is the case,
  // we go back to idle and do nothing.
  always@(posedge clk)
  begin
    if (reset)
      no_cmd_chg  <= 1'b0;
    else if (no_chg_cnt == 3'h6) // might be 5
      no_cmd_chg  <= 1'b1;
    else
      no_cmd_chg  <= 1'b0;
  end
  
  // The search has ended when we have finished
  // checking all of the state_cmd elements.
  always@(posedge clk)
  begin
    if (reset)
      end_search  <= 1'b0;
    else if (cmd_indx == 3'h5)
      end_search  <= 1'b1;
    else
      end_search  <= 1'b0;
  end
  
  // Compare to see if the current state_cmd and the 
  // previous state_cmd are different.  
  always@(posedge clk)
  begin
    if (reset)
      cmd_diff  <= 1'b0;
    else if (state_cmd[cmd_indx] != prev_ste_cmd[cmd_indx])
      cmd_diff  <= 1'b1;
    else
      cmd_diff  <= 1'b0;
  end
  
  // If the state_cmd[index] is 1, it is an open solenoid command.  
  always@(posedge clk)
  begin
    if (reset)
      open_cmd  <= 1'b0;
    else if (state_cmd[cmd_indx] == 1'b1)
      open_cmd  <= 1'b1;
    else
      open_cmd  <= 1'b0;
  end
  
  // If DV_CLOSE_sig = 1, we're at state S16 or state S27 and if all 
  // the EVPs are zeros, all the necessary solenoid(s) have closed,  
  // we are done with homing.
  always@(posedge clk)
  begin
    if (reset)
      finish_home  <= 1'b0;
    else if ((DV_CLOSE_sig  == 1'b1) && (current_state == S16 | 
          current_state == S27) && EVP1_sig == 1'b0 
          && EVP2_sig == 1'b0 &&  EVP3_sig == 1'b0 && EVP4_sig == 1'b0 &&  
          EVP5_sig == 1'b0 && EVP6_sig == 1'b0) 
      finish_home  <= 1'b1;
    else 
      finish_home  <= 1'b0;
  end
  
  // If DV_OPEN_sig = 1, current state = S22 and if all the EVPs are zeros,
  // all the necessary solenoid(s) have opened, we are done with 
  // opening.
  always@(posedge clk)
  begin
    if (reset)
      finish_move  <= 1'b0;
    else if ((DV_OPEN_sig  == 1'b1) && (current_state == S22) && EVP1_sig == 1'b0 && EVP2_sig == 1'b0 &&  EVP3_sig == 1'b0 && EVP4_sig == 1'b0 &&  EVP5_sig == 1'b0 && EVP6_sig == 1'b0) 
      finish_move  <= 1'b1;
    else 
      finish_move  <= 1'b0;
  end
  
  always@(posedge clk)
  begin
    if (reset) begin
      DV1P1_below_open_lim <= 10'h000;
      DV1P2_below_open_lim <= 10'h000;
      DV2P1_below_open_lim <= 10'h000;
      DV2P2_below_open_lim <= 10'h000;
      DV3P1_below_open_lim <= 10'h000;
      DV3P2_below_open_lim <= 10'h000;
    end else if (strb_load) begin
      DV1P1_below_open_lim <= DV1P1_open_lim - 10'h050;
      DV1P2_below_open_lim <= DV1P1_open_lim - 10'h050;
      DV2P1_below_open_lim <= DV2P1_open_lim - 10'h050;
      DV2P2_below_open_lim <= DV2P1_open_lim - 10'h050;
      DV3P1_below_open_lim <= DV3P1_open_lim - 10'h050;
      DV3P2_below_open_lim <= DV3P1_open_lim - 10'h050;
    end
  end          
  
  // If open_mem element is one, we know we need the open solenoid limit.
  // If the close_mem element is one, we know we need the close 
  // solenoid limit.
  // For EVP1_sig.
  always@(posedge clk)
  begin
    if (reset) 
      stop_lim_0        <= 10'h000;
    else if (open_mem[5] == 1'b1)
      stop_lim_0        <= DV1P1_close_lim;
    else if (close_mem[5] == 1'b1) 
      stop_lim_0        <= DV1P1_open_lim;
    else
      stop_lim_0        <= stop_lim_0;
  end
  // For EVP2_sig.
  always@(posedge clk)
  begin
    if (reset) 
      stop_lim_1        <= 10'h000;
    else if (open_mem[4] == 1'b1)
      stop_lim_1        <= DV1P2_close_lim;
    else if (close_mem[4] == 1'b1) 
      stop_lim_1        <= DV1P2_open_lim;
    else
      stop_lim_1        <= stop_lim_1;
  end
  // For EVP3_sig.
  always@(posedge clk)
  begin
    if (reset) 
      stop_lim_2        <= 10'h000;
    else if (open_mem[3] == 1'b1)
      stop_lim_2        <= DV2P1_close_lim;
    else if (close_mem[3] == 1'b1) 
      stop_lim_2        <= DV2P1_open_lim;
    else
      stop_lim_2        <= stop_lim_2;
  end
  // For EVP4_sig.
  always@(posedge clk)
  begin
    if (reset) 
      stop_lim_3        <= 10'h000;
    else if (open_mem[0] == 1'b1)
      stop_lim_3        <= DV2P2_close_lim;
    else if (close_mem[0] == 1'b1) 
      stop_lim_3        <= DV2P2_open_lim;
    else
      stop_lim_3        <= stop_lim_3;
  end
  // For EVP5_sig.
  always@(posedge clk)
  begin
    if (reset) 
      stop_lim_4        <= 10'h000;
    else if (open_mem[1] == 1'b1)
      stop_lim_4        <= DV3P1_close_lim;
    else if (close_mem[1] == 1'b1) 
      stop_lim_4        <= DV3P1_open_lim;
    else
      stop_lim_4        <= stop_lim_4;
  end
  // For EVP6_sig.
  always@(posedge clk)
  begin
    if (reset) 
      stop_lim_5        <= 10'h000;
    else if (open_mem[2] == 1'b1)
      stop_lim_5        <= DV3P2_close_lim;
    else if (close_mem[2] == 1'b1) 
      stop_lim_5        <= DV3P2_open_lim;
    else
      stop_lim_5        <= stop_lim_5;
  end

  //---------------------------------------------------------------
  //
  //  Counts for 1/2 second after starting to move solenoid. 
  defparam gen_mov_cntr.dw   = 28;
  defparam gen_mov_cntr.max  = TIMEOUT_CNTS;
  //---------------------------------------------------------------
  CounterSeq gen_mov_cntr 
  (
    .clk(clk), // 50 MHz system clk
    .reset(reset),
    .enable(1'b1),
    .start_strb(mov_cntr_strb),
    .cntr(), 
    .strb(timeout_strb)
  );  
  
  //---------------------------------------------------------------
  //
  //  Counts for 5 ms before switching on open or close.
  // Also, wait 5 ms before turning on EVPs after shutting off
  // open or close.
  defparam gen_wait_cntr.dw   = 20;
  defparam gen_wait_cntr.max  = WAIT_CNTS;
  //---------------------------------------------------------------
  CounterSeq gen_wait_cntr 
  (
    .clk(clk), // 50 MHz system clk
    .reset(reset),
    .enable(1'b1),
    .start_strb(wt_cntr_strb),
    .cntr(), 
    .strb(wt_done_strb)
  );
    
  // For monitoring adc difference state machine.  
  // Synchronous (sequential) state for determining adc change.
  // We take a difference after each counter is finished.
  always@(posedge clk)
  begin
    if (reset)
      cur_ste <= S00adc;
    else
      cur_ste <= nxt_ste;
  end  
  
  // State transitions (combinational) for determining adc change.
  always@(cur_ste, adc_diff_1_sl, adc_diff_2_sl, adc_diff_3_sl,
        adc_diff_4_sl, adc_diff_5_sl, adc_diff_6_sl, strt_adc_mon,
        DV1P1_sense, DV1P2_sense, DV2P1_sense, DV2P2_sense, DV3P1_sense, 
        DV3P2_sense, finish_move, cur_adc_P1_sl, cur_adc_P2_sl, 
        cur_adc_P3_sl, cur_adc_P4_sl, cur_adc_P5_sl,  cur_adc_P6_sl, 
        stop_motor_P1, stop_motor_P2,  stop_motor_P3, stop_motor_P4, 
        stop_motor_P5, stop_motor_P6, time_up)
  begin
    // State machine defaults.
    cur_adc_P1            <= 10'h000;
    cur_adc_P2            <= 10'h000;
    cur_adc_P3            <= 10'h000;
    cur_adc_P4            <= 10'h000;
    cur_adc_P5            <= 10'h000;
    cur_adc_P6            <= 10'h000;
          
    strt_cntr             <= 1'b0;
    
    adc_diff_1            <= 10'h000;
    adc_diff_2            <= 10'h000;
    adc_diff_3            <= 10'h000;
    adc_diff_4            <= 10'h000;
    adc_diff_5            <= 10'h000;
    adc_diff_6            <= 10'h000;
    
    nxt_ste              <= cur_ste;
    case (cur_ste)
      S00adc:  // Idle state
        begin  
          cur_adc_P1      <= cur_adc_P1_sl;
          cur_adc_P2      <= cur_adc_P2_sl;
          cur_adc_P3      <= cur_adc_P3_sl;
          cur_adc_P4      <= cur_adc_P4_sl;
          cur_adc_P5      <= cur_adc_P5_sl;
          cur_adc_P6      <= cur_adc_P6_sl;
          
          strt_cntr       <= 1'b0;
          
          adc_diff_1      <= adc_diff_1_sl;
          adc_diff_2      <= adc_diff_2_sl;
          adc_diff_3      <= adc_diff_3_sl;
          adc_diff_4      <= adc_diff_4_sl;
          adc_diff_5      <= adc_diff_5_sl;
          adc_diff_6      <= adc_diff_6_sl;
          
          if (strt_adc_mon)
            nxt_ste      <= S01adc;
          else
            nxt_ste       <= S00adc;
        end
      S01adc:  // Start counter.
        begin  
          // capture adc at beginning of counter.
          cur_adc_P1      <= DV1P1_sense; 
          cur_adc_P2      <= DV1P2_sense;
          cur_adc_P3      <= DV2P1_sense;
          cur_adc_P4      <= DV2P2_sense;
          cur_adc_P5      <= DV3P1_sense;
          cur_adc_P6      <= DV3P2_sense;
          
          strt_cntr       <= 1'b1;
          
          adc_diff_1      <= adc_diff_1_sl;
          adc_diff_2      <= adc_diff_2_sl;
          adc_diff_3      <= adc_diff_3_sl;
          adc_diff_4      <= adc_diff_4_sl;
          adc_diff_5      <= adc_diff_5_sl;
          adc_diff_6      <= adc_diff_6_sl;
          
          nxt_ste         <= S02adc;
        end
      S02adc:  // Wait to find next adc count.
        begin  
          cur_adc_P1      <= cur_adc_P1_sl;
          cur_adc_P2      <= cur_adc_P2_sl;
          cur_adc_P3      <= cur_adc_P3_sl;
          cur_adc_P4      <= cur_adc_P4_sl;
          cur_adc_P5      <= cur_adc_P5_sl;
          cur_adc_P6      <= cur_adc_P6_sl;
          
          strt_cntr       <= 1'b0;
          
          adc_diff_1      <= adc_diff_1_sl;
          adc_diff_2      <= adc_diff_2_sl;
          adc_diff_3      <= adc_diff_3_sl;
          adc_diff_4      <= adc_diff_4_sl;
          adc_diff_5      <= adc_diff_5_sl;
          adc_diff_6      <= adc_diff_6_sl;
          
          if (time_up) // Time to find adc difference.
            nxt_ste       <= S03adc;
          else if (finish_move)
            nxt_ste       <= S00adc;
          else
            nxt_ste       <= S02adc;
        end
      S03adc:  // Find the adc count difference.
        begin  
          cur_adc_P1      <= cur_adc_P1_sl;
          cur_adc_P2      <= cur_adc_P2_sl;
          cur_adc_P3      <= cur_adc_P3_sl;
          cur_adc_P4      <= cur_adc_P4_sl;
          cur_adc_P5      <= cur_adc_P5_sl;
          cur_adc_P6      <= cur_adc_P6_sl;
          
          strt_cntr       <= 1'b0;
          
          // Capture adc count at end of counter.
          // Also, find the difference.
          adc_diff_1      <= DV1P1_sense - cur_adc_P1_sl;
          adc_diff_2      <= DV1P2_sense - cur_adc_P2_sl;
          adc_diff_3      <= DV2P1_sense - cur_adc_P3_sl;
          adc_diff_4      <= DV2P2_sense - cur_adc_P4_sl;
          adc_diff_5      <= DV3P1_sense - cur_adc_P5_sl;
          adc_diff_6      <= DV3P2_sense - cur_adc_P6_sl;
          
          nxt_ste         <= S04adc;
        end
      S04adc:  // Decide whether to start counter again.
        begin  
          cur_adc_P1      <= cur_adc_P1_sl;
          cur_adc_P2      <= cur_adc_P2_sl;
          cur_adc_P3      <= cur_adc_P3_sl;
          cur_adc_P4      <= cur_adc_P4_sl;
          cur_adc_P5      <= cur_adc_P5_sl;
          cur_adc_P6      <= cur_adc_P6_sl;
          
          strt_cntr      <= 1'b0;
          
          adc_diff_1      <= adc_diff_1_sl;
          adc_diff_2      <= adc_diff_2_sl;
          adc_diff_3      <= adc_diff_3_sl;
          adc_diff_4      <= adc_diff_4_sl;
          adc_diff_5      <= adc_diff_5_sl;
          adc_diff_6      <= adc_diff_6_sl;
          
          // If all motors are done or reached destination go to idle.
          // Else, restart counter.
          if ((stop_motor_P1 && stop_motor_P2 && stop_motor_P3 &&
            stop_motor_P4 && stop_motor_P5 && stop_motor_P6) | 
            finish_move)          
            nxt_ste       <= S00adc;
          else
            nxt_ste       <= S01adc;
        end
      default:    
        nxt_ste           <= S00adc;
    endcase
  end
  // End of state machine.
  
  // Sensitivity list item of adc_diff_1.
  always@(posedge clk)
  begin
    if (reset)
      adc_diff_1_sl  <= 10'h000;
    else
      adc_diff_1_sl  <= adc_diff_1;
  end 
  
  // Sensitivity list item of adc_diff_2.
  always@(posedge clk)
  begin
    if (reset)
      adc_diff_2_sl  <= 10'h000;
    else
      adc_diff_2_sl  <= adc_diff_2;
  end 
  
  // Sensitivity list item of adc_diff_3.
  always@(posedge clk)
  begin
    if (reset)
      adc_diff_3_sl  <= 10'h000;
    else
      adc_diff_3_sl  <= adc_diff_3;
  end 
  
  // Sensitivity list item of adc_diff_4.
  always@(posedge clk)
  begin
    if (reset)
      adc_diff_4_sl  <= 10'h000;
    else
      adc_diff_4_sl  <= adc_diff_4;
  end 
  
  // Sensitivity list item of adc_diff_5.
  always@(posedge clk)
  begin
    if (reset)
      adc_diff_5_sl  <= 10'h000;
    else
      adc_diff_5_sl  <= adc_diff_5;
  end 
  
  // Sensitivity list item of adc_diff_6.
  always@(posedge clk)
  begin
    if (reset)
      adc_diff_6_sl  <= 10'h000;
    else
      adc_diff_6_sl  <= adc_diff_6;
  end 
  
  // Sensitivity list item of cur_adc_P1.
  always@(posedge clk)
  begin
    if (reset)
      cur_adc_P1_sl  <= 10'h000;
    else
      cur_adc_P1_sl  <= cur_adc_P1;
  end 
  
  // Sensitivity list item of cur_adc_P2.
  always@(posedge clk)
  begin
    if (reset)
      cur_adc_P2_sl  <= 10'h000;
    else
      cur_adc_P2_sl  <= cur_adc_P2;
  end 
  
  // Sensitivity list item of cur_adc_P3.
  always@(posedge clk)
  begin
    if (reset)
      cur_adc_P3_sl  <= 10'h000;
    else
      cur_adc_P3_sl  <= cur_adc_P3;
  end 
  
  // Sensitivity list item of cur_adc_P4.
  always@(posedge clk)
  begin
    if (reset)
      cur_adc_P4_sl  <= 10'h000;
    else
      cur_adc_P4_sl  <= cur_adc_P4;
  end 
  
  // Sensitivity list item of cur_adc_P5.
  always@(posedge clk)
  begin
    if (reset)
      cur_adc_P5_sl  <= 10'h000;
    else
      cur_adc_P5_sl  <= cur_adc_P5;
  end 
  
  // Sensitivity list item of cur_adc_P6.
  always@(posedge clk)
  begin
    if (reset)
      cur_adc_P6_sl  <= 10'h000;
    else
      cur_adc_P6_sl  <= cur_adc_P6;
  end 
      
  
  // Decide to stop motor P1.  Use a parameter for adc_diff.
  always@(posedge clk)
  begin
    if (reset)
      stop_motor_P1  <= 1'b0;
      // 15 counts means 30 mV.
    else if ((cur_ste == S03adc) && adc_diff_1 <= 25) // 50 mv
      stop_motor_P1  <= 1'b1;
    else
      stop_motor_P1  <= 1'b0;
  end 
  
  // Decide to stop motor P2.
  always@(posedge clk)
  begin
    if (reset)
      stop_motor_P2  <= 1'b0;
    else if ((cur_ste == S03adc) && adc_diff_2 <= 25)
      stop_motor_P2  <= 1'b1;
    else
      stop_motor_P2  <= 1'b0;
  end 
  
  // Decide to stop motor P3.
  always@(posedge clk)
  begin
    if (reset)
      stop_motor_P3  <= 1'b0;
    else if ((cur_ste == S03adc) && adc_diff_3 <= 25)
      stop_motor_P3  <= 1'b1;
    else
      stop_motor_P3  <= 1'b0;
  end 
  
  // Decide to stop motor P4.
  always@(posedge clk)
  begin
    if (reset)
      stop_motor_P4  <= 1'b0;
    else if ((cur_ste == S03adc) && adc_diff_4 <= 25)
      stop_motor_P4  <= 1'b1;
    else
      stop_motor_P4  <= 1'b0;
  end 
  
  // Decide to stop motor P5.
  always@(posedge clk)
  begin
    if (reset)
      stop_motor_P5  <= 1'b0;
    else if ((cur_ste == S03adc) && adc_diff_5 <= 25)
      stop_motor_P5  <= 1'b1;
    else
      stop_motor_P5  <= 1'b0;
  end
  
  // Decide to stop motor P6.
  always@(posedge clk)
  begin
    if (reset)
      stop_motor_P6  <= 1'b0;
    else if ((cur_ste == S03adc) && adc_diff_6 <= 25)
      stop_motor_P6  <= 1'b1;
    else
      stop_motor_P6  <= 1'b0;
  end 
  
  //---------------------------------------------------------------
  //
  //  Counts for 100 ms before comparing the current adc count and
  // previous adc count.
  defparam wait_adc_chg_cntr.dw   = 24;
  defparam wait_adc_chg_cntr.max  = WAIT_ADC_CNT_CHG;
  //---------------------------------------------------------------
  CounterSeq wait_adc_chg_cntr 
  (
    .clk(clk), // 50 MHz system clk
    .reset(reset),
    .enable(1'b1),
    .start_strb(strt_cntr),
    .cntr(), 
    .strb(time_up)
  );  
  
  // Drive outputs with a gate
  always@(posedge clk)
  begin
    if (reset) begin
      DV_OPEN   <= 1'b0;
      DV_CLOSE  <= 1'b0;
      EVP1     <= 1'b0;
      EVP2     <= 1'b0;
      EVP3     <= 1'b0;
      EVP4     <= 1'b0;
      EVP5     <= 1'b0;
      EVP6     <= 1'b0;
    end else begin
      DV_OPEN   <= DV_OPEN_sig;
      DV_CLOSE  <= DV_CLOSE_sig;
      EVP1     <= EVP1_sig;
      EVP2     <= EVP2_sig;
      EVP3     <= EVP3_sig;
      EVP4     <= EVP4_sig;
      EVP5     <= EVP5_sig;
      EVP6     <= EVP6_sig;
    end  
  end  
    
endmodule
