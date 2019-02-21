//------------------------------------------------------------------------------------------//
//  Module:     StateMachine_IO
//  Project:    
//  Version:    0.01-1
//
//  Description: 
//
//-----------------------------------------------------------------------------------------//  
module StateMachine_IO
#( parameter LS = 36)
(  
  input                 clk,                  // System Clock 
  input                 reset,                // System Reset (Syncronous) 
  input                 enable,               // System enable 
  input                 sys_tmr_strb,         // System Timer Strobe  
  input                 estop_pressed,        // Flag to indicate estop_pressed.
  
  input     [35:0]      uic_command_reg,      // Bit Command Register From UIC              0x3e
  input      [3:0]      con_door_status,      // Controller Door Status                     0x3d
  input                 ioc_bprime_done,      // Flag to indicate that blood prime is done  0x3c[18] 
  input                 ioc_dprime_done,      // Flag to indicate that blood prime is done  0x3b[18] 
  input                 ioc_dprime_en,        // Enable flag to be running dprime           0x3a[18] 
  input                 ioc_treatment_en,     // Enable flag to be running treatment        0x39[18] 
  input                 ioc_treatment_done,   // Flag to indicate that treatment is done    0x38[18]
  input                 ioc_rinse_en,         // Flag to enable rinse                       0x37[18]
  input                 ioc_rinse_done,       // Flag to indicate rinse is done             0x36[18]
  input                 ioc_empty_en,         // Flag to indicate empty                     0x35[18]
  input    [35:0]       saf_alarms,           // Register of safety alarms                  0x25
  input     [2:0]       saf_alarm_status,     // Alarm status                               0x26 [20:18]
  
  input                 seq_list_done_strb,   // Strobe that sequence list is done
  output reg [LS-1:0]   seq_list_en,          // Flags to enable sequences    
  output reg [35:0]     io_state,             // identifies current IO state
  output reg [35:0]     alarm_state,          // identifies current Alarm state
  output reg [15:0]     state_debug           // Register to help test state machine
);                                                                                           


  // STATES
  localparam S00_RESET               = 6'h00;
  localparam S01_POR                 = 6'h01;
  localparam S02_INIT_BRD            = 6'h02;
  localparam S03_INIT_SYS            = 6'h03;
  localparam S04_BOOT_TIME           = 6'h04;
  localparam S05_CMD_RDY             = 6'h05;
  localparam S06_DOOR_OPEN           = 6'h06;
  localparam S07_DOOR_CLOSE          = 6'h07;
  localparam S08_PRE_PRIME           = 6'h08;
  localparam S09_PRIME               = 6'h09;
  localparam S10_BPRIME_DONE         = 6'h0a;
  localparam S11_RE_PRIME_OR_CIRC    = 6'h0b;          
  localparam S12_BLOOD_REPRIME       = 6'h0c;
  localparam S13_BLOOD_RECIRC        = 6'h0d;            
  localparam S14_START_ALARMS        = 6'h0e;          
  localparam S15_ALARM_PRESSURE      = 6'h0f;  
  localparam S16_DELAY               = 6'h10;
  localparam S17_ALARM_AIRBUBBLE     = 6'h11; 
  localparam S18_DELAY               = 6'h12;
  localparam S19_ALARM_BLOODLEAK     = 6'h13;
  localparam S20_DELAY               = 6'h14;
  localparam S21_ALARM_AMMONIA       = 6'h15;
  localparam S22_DELAY               = 6'h16; 
  localparam S23_ALARM_ELECTROLYTE   = 6'h17; 
  localparam S24_DELAY               = 6'h18;
  localparam S25_ALARM_TEMP          = 6'h19; 
  localparam S26_DELAY               = 6'h1a;
  localparam S27_GET_DIAL_TEMP       = 6'h1b;
  localparam S28_BLOOD_FLUSH         = 6'h1c;
  localparam S29_TREATMENT_WAIT      = 6'h1d;
  localparam S30_TREATMENT           = 6'h1e;
  localparam S31_DELAY               = 6'h1f;
  localparam S32_TREATMENT_DONE      = 6'h20;
  localparam S33_DELAY               = 6'h21;
  localparam S34_TREATMENT_STOPPED   = 6'h22;
  localparam S35_RINSEBACK           = 6'h23;
  localparam S36_RINSEBACK_DONE      = 6'h24;
  localparam S37_DELAY               = 6'h25;
  localparam S38_EMPTY               = 6'h26;
  localparam S39_TREATMENT_OVER      = 6'h27;
  
  //Alarm States
  localparam A00_NORMAL              = 4'h0;
  localparam A01_DETECTION_01        = 4'h1;
  localparam A02_DETECTION_02        = 4'h2;
  localparam A03_DETECTION_03        = 4'h3;
  localparam A04_ALARM               = 4'h4;  
  localparam A05_ALERT               = 4'h5;  
  localparam A06_RESUME_ALARM        = 4'h6;  
  localparam A07_RESUME_ALERT        = 4'h7;  
  localparam A08_RESUME_SYNC1        = 4'h8;
  localparam A09_RESUME_SYNC2        = 4'h9;
  localparam A10_RESUME_SYNC3        = 4'ha;
  localparam A11_RESUME_SYNC4        = 4'hb;
  localparam A12_SHUTDOWN            = 4'hc;  
  
  
  wire          uic_open_door_enable;
  wire          uic_close_door_enable;
  wire          seq_en_stop_all;
  wire          por_cnt_strb;
  wire          boot_cnt_strb;

  reg           uic_unlock_door;
  reg           uic_unlock_door_Z1;
  reg           uic_unlock_cmd;
  wire          open_command;
  
  reg           uic_lock_door;
  reg           uic_lock_door_Z1;
  reg           uic_lock_cmd;
  wire          close_command;
  
  reg  [3:0]    puc_door_status;
  reg  [3:0]    puc_door_status_Z1;
  reg           puc_door_change_cmd;
  wire          event_command;  
  
  reg           por_start_strb;
  reg           por_cnt_en;
  reg           delay36_done;
  reg           boot_start_strb;
  reg           boot_cnt_en;
  reg           delay32_done;
  
  reg           bootup_open_door;  
  wire          seq_srv_open_door;
  
  reg           seq_set_por;
  wire          seq_srv_por;
  
  //reg           seq_set_initialize;
  //wire          seq_srv_initialize;
  
  wire          uic_door_event_enable;
  
  wire          uic_pre_prime_enable;
  wire          uic_pre_prime_trigger;
  wire          uic_pre_prime_cmd;
    
  wire          uic_bp_prime_enable; 
  wire          uic_bp_prime_trigger;  
  
  wire          uic_dp_prime_enable; 
  wire          uic_dp_prime_trigger;  
  
  wire          uic_bp_prime_pause_enable;
  wire          uic_dp_prime_pause_enable;
  
  wire          uic_bprime_done_enable;
  wire          prime_done_cmd;
  
  wire          uic_dprime_done_enable;
  wire          recirc_done_cmd;
    
  wire          uic_reprime_enable;
  wire          uic_reprime_trigger;
  wire          blood_reprime_cmd;
  wire          uic_reprime_done_enable;
  wire          reprime_done_cmd;
  
  wire          uic_recirc_enable;
  wire          blood_recirc_cmd;
  wire          uic_recirc_trigger;

  wire          uic_recirc_done_enable;
  wire          uic_recirc_done_trigger;

  wire          uic_start_alarms_enable;
  wire          uic_start_alarms_trigger;
  wire          start_alarms_cmd;

  wire          uic_alarm_pressure_enable;
  wire          uic_alarm_pressure_trigger;
  wire          alarm_pressure_done_cmd;
  
  wire          uic_alarm_air_bubble_enable;
  wire          uic_alarm_air_bubble_trigger;
  wire          alarm_air_bubble_done_cmd;

  wire          uic_alarm_blood_leak_enable;
  wire          uic_alarm_blood_leak_trigger;
  wire          alarm_blood_leak_done_cmd;

  wire          uic_alarm_ammonia_enable;
  wire          uic_alarm_ammonia_trigger;
  wire          alarm_ammonia_done_cmd;

  wire          uic_alarm_electrolyte_enable;
  wire          uic_alarm_electrolyte_trigger;
  wire          alarm_electrolyte_done_cmd;

  wire          uic_alarm_temp_enable;
  wire          uic_alarm_temp_trigger;
  wire          alarm_temp_done_cmd;
  
  wire          uic_dial_temp_enable;
  wire          uic_dial_temp_trigger;

  wire          stop_recirc_cmd;
  
  wire          uic_blood_flush_enable;
  wire          uic_blood_flush_trigger;
  
  wire          uic_blood_flush_stop_enable;
  wire          uic_blood_flush_stop_trigger;
  wire          blood_flush_done_cmd;

  wire          uic_treatment_init_enable;
  wire          uic_treatment_init_trigger;
  wire          treatment_cmd;

  wire          uic_treatment_enable;
  wire          uic_treatment_trigger;
  wire          uic_treatment_forced;

  wire          uic_treatment_pause_enable;
  wire          uic_treatment_pause_trigger;
  wire          treatment_stop_cmd;

  wire          uic_treatment_done_enable;
  wire          uic_treatment_done_trigger;
  wire          treatment_done_cmd;

  wire          uic_treatment_stopped_enable;
  wire          uic_treatment_stopped_trigger;
  wire          treatment_stopped_cmd;

  wire          uic_rinse_enable;
  wire          uic_rinse_trigger;
  wire          uic_rinse_force;
  wire          rinse_done_cmd;
  
  wire          uic_rinse_pause_enable;
  wire          uic_rinse_pause_trigger;

  wire          uic_rinse_done_enable;
  wire          uic_rinse_done_trigger;

  wire          uic_empty_enable;
  wire          uic_empty_trigger;
  wire          uic_empty_force;

  wire          uic_empty_stop_enable;
  wire          uic_empty_stop_trigger;
  wire          empty_done_cmd;
  
    
  reg           seq_en_reg_update;  
  reg           seq_en_alarm_audio;  
  reg           seq_en_por;
  reg           seq_en_initialize;
  wire          seq_en_door_event;
  wire          seq_en_close_door;
  wire          seq_en_open_door;  
  wire          seq_en_prime_init;
  wire          seq_en_set_temp;
  wire          seq_en_bp_prime;
  wire          seq_en_dp_prime;
  wire          seq_en_bp_pause_prime;
  wire          seq_en_dp_pause_prime;
  wire          seq_en_bprime_done;
  wire          seq_en_dprime_done;
  wire          seq_en_reprime;
  wire          seq_en_reprime_done;  
  wire          seq_en_recirc;
  wire          seq_en_recirc_done;  
  wire          seq_en_alarm_pressure;
  wire          seq_en_alarm_air_bubble;
  wire          seq_en_alarm_blood_leak;
  wire          seq_en_alarm_ammonia;
  wire          seq_en_alarm_electrolyte;
  wire          seq_en_alarm_temp;
  wire          seq_en_dial_temp;
  wire          seq_en_blood_flush;
  wire          seq_en_blood_flush_stop;
  wire          seq_en_treatment_init;
  wire          seq_en_treatment;
  wire          seq_en_treatment_finished;
  wire          seq_en_treatment_paused;
  wire          seq_en_treatment_done;
  wire          seq_en_treatment_stopped;
  wire          seq_en_rinse;
  wire          seq_en_rinse_pause;
  wire          seq_en_rinse_done;
  wire          seq_en_empty;
  wire          seq_en_empty_stop;
  
  
  reg [5:0]     current_state;
  reg [5:0]     last_state;
  reg [5:0]     last_state_Z1;
  reg [5:0]     next_state;  
  reg           change_strb;
  
  reg [3:0]     current_alarm_state;
//  reg [3:0]     last_alarm_state;
//  reg [3:0]     last_alarm_state_Z1;
  reg [3:0]     next_alarm_state;    
//  reg           change_alarm_strb;  
  
  reg           sys_tmr_strb_Z1;
  reg           sys_tmr_strb_Z2;
  reg           sys_tmr_strb_Z3;
  
  wire [LS-1:0] seq_list_bits;
  
  wire          monitor_ready_enable;
  wire          monitor_ready_trigger;
  wire          monitor_ready_force;
  wire          seq_en_monitor_ready;  
  
  wire          alarm_detect_enable;
  wire          alarm_detect_trigger;
  wire          alarm_detect_force;
  wire          seq_en_alarm_setup;
  
  wire          alert_detect_enable;
  wire          alert_detect_trigger;
  wire          alert_detect_force;
  wire          seq_en_alert_setup; 
  
  wire          alarm_handle_enable;
  wire          alarm_handle_trigger;
  wire          alarm_handle_force;
  wire          seq_en_alarm_handle;  

  wire          alert_handle_enable;
  wire          alert_handle_trigger;
  wire          alert_handle_force;
  wire          seq_en_alert_handle;   

  wire          alarm_resume_enable;
  wire          alarm_resume_trigger;
  wire          alarm_resume_force;
  wire          seq_en_alarm_resume;  

  wire          alert_resume_enable;
  wire          alert_resume_trigger;
  wire          alert_resume_force;
  wire          seq_en_alert_resume;   

  wire          shutdown_enable;
  wire          shutdown_trigger;
  wire          shutdown_force;
  wire          seq_en_shutdown;   
  
  wire          resume_alarm;
  wire          resume_alert;
  wire          sys_shutdown;
  
  wire          alarm_alert_detected;  

  reg [LS-1:0]  sys_state_enabled;
  reg           alarm_detected;
  reg           alert_detected;
  reg           permanent_shutdown;  
  
  
  initial
  begin
    uic_unlock_door     <= 1'b0;
    uic_unlock_door_Z1  <= 1'b0;
    uic_unlock_cmd      <= 1'b0;
    
    uic_lock_door       <= 1'b0;
    uic_lock_door_Z1    <= 1'b0;
    uic_lock_cmd        <= 1'b0;
    
    puc_door_status     <= 4'h0;
    puc_door_status_Z1  <= 4'h0;
    puc_door_change_cmd <= 1'b0;    
    
    por_start_strb      <= 1'b0;
    por_cnt_en          <= 1'b0;
    delay36_done        <= 1'b0;
    boot_start_strb     <= 1'b0;
    boot_cnt_en         <= 1'b0;
    delay32_done        <= 1'b0;
    bootup_open_door    <= 1'b0;    
    
    seq_en_reg_update   <= 1'b0;
    seq_en_alarm_audio  <= 1'b0;
    seq_en_por          <= 1'b0;
    seq_en_initialize   <= 1'b0;
    
    seq_set_por         <= 1'b0;
    //seq_set_initialize  <= 1'b0;
    
    sys_tmr_strb_Z1     <= 1'b0;
    sys_tmr_strb_Z2     <= 1'b0;
    sys_tmr_strb_Z3     <= 1'b0;   
    
    //change_alarm_strb   <= 1'b0;
    current_alarm_state <= 4'h0;
    //last_alarm_state    <= 4'h0;
    //last_alarm_state_Z1 <= 4'h0;
    next_alarm_state    <= 4'h0;
    
    change_strb         <= 1'b0;
    current_state       <= 5'h00;
    last_state          <= 5'h00;
    last_state_Z1       <= 5'h00;
    next_state          <= 5'h00;
    
    seq_list_en         <= {LS{1'b0}};
    
    sys_state_enabled   <= {LS{1'b0}};
    alarm_detected      <= 1'b0;
    alert_detected      <= 1'b0;
    permanent_shutdown  <= 1'b0;
    
    io_state            <= 36'h000000000;
    alarm_state         <= 36'h000000000;
    state_debug         <= 16'h0000;
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
  //    IF DOOR OPEN COMMAND THEN RUN OPEN DOOR
  //    GOTO DOOR OPEN STATE
  //    IF DOOR CLOSE COMMAND THEN RUN CLOSE DOOR
  //    GOTO DOOR CLOSE STATE
  //  6 DOOR OPEN STATE
  //    WAIT FOR 3D TO CHANGE, THEN SEND EVENT
  //    GOTO COMMAND READY
  //  7 DOOR CLOSE STATE
  //    WAIT FOR 3D TO CHANGE, THEN SEND EVENT
  //    GOTO COMMAND READY
    
    
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
  //Allow alarm state to force io state to empty to end treatment
  always@(posedge clk)
  begin
    if (reset)
        current_state <= S00_RESET;
    else if (sys_tmr_strb && permanent_shutdown)
        current_state <= S38_EMPTY;
    else if (sys_tmr_strb)
        current_state <= next_state;      
  end  
  
  //State transitions
  always@(current_state, delay36_done, delay32_done, open_command, close_command, event_command,
          uic_pre_prime_cmd, prime_done_cmd,recirc_done_cmd, blood_reprime_cmd, blood_recirc_cmd,
          reprime_done_cmd, recirc_done_cmd, start_alarms_cmd, alarm_pressure_done_cmd, alarm_air_bubble_done_cmd,
          alarm_blood_leak_done_cmd, alarm_ammonia_done_cmd, alarm_electrolyte_done_cmd, alarm_temp_done_cmd,
          stop_recirc_cmd, blood_flush_done_cmd,treatment_cmd, treatment_done_cmd, treatment_stop_cmd,
          treatment_stopped_cmd, rinse_done_cmd, empty_done_cmd)
  begin
    case (current_state)
      S00_RESET             :     next_state <= S01_POR;
      
      S01_POR               :   if (delay36_done)
                                  next_state <= S02_INIT_BRD;
                                else
                                  next_state <= S01_POR;
      
      S02_INIT_BRD          :     next_state <= S03_INIT_SYS;
      
      S03_INIT_SYS          :     next_state <= S04_BOOT_TIME;
      
      S04_BOOT_TIME         :   if (delay32_done)
                                  next_state <= S05_CMD_RDY;
                                else
                                  next_state <= S04_BOOT_TIME;
      
      S05_CMD_RDY           :   if (open_command)
                                  next_state <= S06_DOOR_OPEN;
                                else if (close_command)  
                                  next_state <= S07_DOOR_CLOSE;
                                else if (uic_pre_prime_cmd)
                                  next_state <= S08_PRE_PRIME;
                                else
                                  next_state <= S05_CMD_RDY;
                        
      S06_DOOR_OPEN         :   if (event_command)
                                  next_state <= S05_CMD_RDY;
                                else      
                                  next_state <= S06_DOOR_OPEN;
      
      S07_DOOR_CLOSE        :   if (event_command)
                                  next_state <= S05_CMD_RDY;
                                else
                                  next_state <= S07_DOOR_CLOSE;

      S08_PRE_PRIME         :     next_state <= S09_PRIME;      
                        
      S09_PRIME             :   if (prime_done_cmd)
                                  next_state <= S10_BPRIME_DONE;
                                else
                                  next_state <= S09_PRIME;
          
      S10_BPRIME_DONE       :     next_state <= S11_RE_PRIME_OR_CIRC;
      
      S11_RE_PRIME_OR_CIRC  :   if (blood_reprime_cmd)     
                                  next_state <= S12_BLOOD_REPRIME;
                                else if (blood_recirc_cmd)
                                  next_state <= S13_BLOOD_RECIRC;
                                else
                                  next_state <= S11_RE_PRIME_OR_CIRC;
                                  
      S12_BLOOD_REPRIME     :   if (reprime_done_cmd)
                                  next_state <= S11_RE_PRIME_OR_CIRC;
                                else 
                                  next_state <= S12_BLOOD_REPRIME;

      S13_BLOOD_RECIRC      :   if (recirc_done_cmd)
                                  next_state <= S14_START_ALARMS;
                                else 
                                  next_state <= S13_BLOOD_RECIRC;
                                  
      S14_START_ALARMS      :   if (start_alarms_cmd)
                                  next_state <= S15_ALARM_PRESSURE;
                                else 
                                  next_state <= S14_START_ALARMS;
                                  
      S15_ALARM_PRESSURE    :   if (alarm_pressure_done_cmd)
                                  next_state <= S16_DELAY;
                                else
                                  next_state <= S15_ALARM_PRESSURE;

      S16_DELAY:                  next_state <= S17_ALARM_AIRBUBBLE;
      
      S17_ALARM_AIRBUBBLE   :   if (alarm_air_bubble_done_cmd)
                                  next_state <= S18_DELAY;
                                else
                                  next_state <= S17_ALARM_AIRBUBBLE;                                  
      
      S18_DELAY:                  next_state <= S19_ALARM_BLOODLEAK;
      
      S19_ALARM_BLOODLEAK   :   if (alarm_blood_leak_done_cmd)
                                  next_state <= S20_DELAY;
                                else
                                  next_state <= S19_ALARM_BLOODLEAK;
      
      S20_DELAY:                  next_state <= S21_ALARM_AMMONIA;
      
      S21_ALARM_AMMONIA     :   if (alarm_ammonia_done_cmd)
                                  next_state <= S22_DELAY;
                                else
                                  next_state <= S21_ALARM_AMMONIA;
      
      S22_DELAY:                  next_state <= S23_ALARM_ELECTROLYTE;
      
      S23_ALARM_ELECTROLYTE :   if (alarm_electrolyte_done_cmd)
                                  next_state <= S24_DELAY;
                                else
                                  next_state <= S23_ALARM_ELECTROLYTE;
      
      S24_DELAY:                  next_state <= S25_ALARM_TEMP;
      
      S25_ALARM_TEMP        :   if (alarm_temp_done_cmd)
                                  next_state <= S26_DELAY;
                                else
                                  next_state <= S25_ALARM_TEMP;
      
      S26_DELAY:                  next_state <= S27_GET_DIAL_TEMP;
      
      S27_GET_DIAL_TEMP     :   if (stop_recirc_cmd)   
                                  next_state <= S28_BLOOD_FLUSH;
                                else  
                                  next_state <= S27_GET_DIAL_TEMP;
      
      S28_BLOOD_FLUSH       :   if (blood_flush_done_cmd) 
                                  next_state <= S29_TREATMENT_WAIT;
                                else  
                                  next_state <= S28_BLOOD_FLUSH;  
            
      S29_TREATMENT_WAIT    :   if (treatment_cmd) 
                                  next_state <= S30_TREATMENT;
                                else  
                                  next_state <= S29_TREATMENT_WAIT;            
      
      S30_TREATMENT         :   if (treatment_done_cmd || treatment_stop_cmd)
                                  next_state <= S31_DELAY;
                                else
                                  next_state <= S30_TREATMENT;
      
      S31_DELAY             :     next_state <= S32_TREATMENT_DONE;
      
      S32_TREATMENT_DONE    :   if (treatment_stopped_cmd)
                                  next_state <= S33_DELAY;
                                else
                                  next_state <= S32_TREATMENT_DONE;                                        
      
      S33_DELAY             :     next_state <= S34_TREATMENT_STOPPED;
      
      S34_TREATMENT_STOPPED :     next_state <= S35_RINSEBACK;     
      
      S35_RINSEBACK         :   if (rinse_done_cmd)
                                  next_state <= S36_RINSEBACK_DONE;
                                else
                                  next_state <= S35_RINSEBACK;
      
      S36_RINSEBACK_DONE    :     next_state <= S37_DELAY;
      
      S37_DELAY             :     next_state <= S38_EMPTY;
      
      S38_EMPTY             :   if (empty_done_cmd)
                                  next_state <= S39_TREATMENT_OVER;
                                else
                                  next_state <= S38_EMPTY;
      
      S39_TREATMENT_OVER    :     next_state <= S39_TREATMENT_OVER;
            
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
    defparam POR_State_Cntr_i.dw = 6;
    defparam POR_State_Cntr_i.max = 6'h23;
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
      delay36_done <= 1'b0;
    else if (por_cnt_strb)
      delay36_done <= 1'b1;
  end
  
//--------- END POR COUNTER  --------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//-------- INITIALIZE BOARDS---------------------------------------------------------------//    
    
  //---- STATE TRANSITION FOR POR         -------------------------------------------------//
   
  // Initialize enable  
  always@(posedge clk)
  begin
    if (reset || seq_srv_por)
      seq_set_por <= 1'b0;
    else if (current_state == S02_INIT_BRD && change_strb)
      seq_set_por <= 1'b1;
  end
  
  // Initialize command set
  always@(posedge clk)
  begin
    if (reset || seq_srv_por)
      seq_en_por <= 1'b0;
    else if (seq_set_por && sys_tmr_strb)
      seq_en_por <= 1'b1;
  end
    
  // Initialize command serviced
  assign seq_srv_por = seq_en_por & seq_list_done_strb;
  
  //---- END STATE TRANSITION FOR POR         ---------------------------------------------//


  //---- STATE TRANSITION FOR INITIALIAZE -------------------------------------------------//
   
  // Initialize while boot
  always@(posedge clk)
  begin
    if (reset)
      seq_en_initialize <= 1'b0;
    else if (current_state == S04_BOOT_TIME)
      seq_en_initialize <= 1'b1;
    else  
      seq_en_initialize <= 1'b0;
  end   
  
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
    defparam Boot_State_Cntr_i.dw = 5;
    defparam Boot_State_Cntr_i.max = 5'h1F;
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
      delay32_done <= 1'b0;
    else if (boot_cnt_strb)
      delay32_done <= 1'b1;
  end
      
  // Set the door open command on boot up
  always@(posedge clk)
  begin
    if (reset || seq_srv_open_door)
      bootup_open_door <= 1'b0;
    else if (boot_start_strb)
      bootup_open_door <= 1'b1;
  end   
     
//------------- END BOOT COUNTER   --------------------------------------------------------//  
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//------------- REGISTER UPDATES ----------------------------------------------------------// 
  
  // Register Update enables
  always@(posedge clk)
  begin
    if (reset)
      seq_en_reg_update <= 1'b0;
    else if (current_state != S00_RESET && current_state != S01_POR && sys_tmr_strb_Z3)
      seq_en_reg_update <= 1'b1;
  end  
     
//------------- END REGISTER UPDATES ------------------------------------------------------// 
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//------------- ALARM AUDIO --------------------------------------------------------------// 
  
  // Register Update enables
  always@(posedge clk)
  begin
    if (reset)
      seq_en_alarm_audio <= 1'b0;
    else if (current_state != S00_RESET && current_state != S01_POR && sys_tmr_strb_Z3)
      seq_en_alarm_audio <= 1'b1;
  end  
     
//------------- END ALARM AUDIO -----------------------------------------------------------// 
//-----------------------------------------------------------------------------------------//


//-----------------------------------------------------------------------------------------//  
//------------ CMD READY STATE ------------------------------------------------------------//  

  //---- STATE TRANSITION FOR DOOR OPEN ---------------------------------------------------//
   
  // Enable transition based on current state and not open bit
  assign uic_open_door_enable    = ((current_state == S05_CMD_RDY) | (current_state == S39_TREATMENT_OVER)) ? 1'b1 : 1'b0;   
   
  // State transition
  defparam ST_uic_open_door_i.TW = 1;
  StateTransition ST_uic_open_door_i
  (
    .clk(clk),                                // System clock                                 input 
    .reset(reset),                            // System reset (Syncronous)                    input 
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe                          input 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done  input 
    .enable(uic_open_door_enable),            // Enable toggle                                input 
    .triggerEn(uic_command_reg[1]),           // Signal to trigger state transition           input 
    .forcedEn(bootup_open_door),              // Signal to force enable                       input 
    .transitionCmd(open_command),             // Command                                      output
    .sequenceEn(seq_en_open_door),            // Sequence Enable                              output
    .seq_serviced_strb(seq_srv_open_door)     // Sequence Serviced                            output
  );
  
  //---- END STATE TRANSITION FOR DOOR OPEN ----------------------------------------------//
  
  
  //---- STATE TRANSITION FOR DOOR CLOSE -------------------------------------------------//
   
  // Enable transition based on current state and not open bit
  assign uic_close_door_enable    = (((current_state == S05_CMD_RDY) | (current_state == S39_TREATMENT_OVER)) & ~uic_command_reg[1]) ? 1'b1 : 1'b0;   
   
  // State transition
  defparam ST_uic_close_door_i.TW = 1;
  StateTransition ST_uic_close_door_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done  
    .enable(uic_close_door_enable),           // Enable toggle
    .triggerEn(uic_command_reg[0]),           // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(close_command),            // Command
    .sequenceEn(seq_en_close_door),           // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR DOOR CLOSE ----------------------------------------------//
 
    
    
//------------ END CMD READY STATE --------------------------------------------------------//    
//-----------------------------------------------------------------------------------------//  
  
//-----------------------------------------------------------------------------------------//
//------------ OPEN/CLOSE EVENT -----------------------------------------------------------//


  // Only enable door event if commanded open or closed
  assign uic_door_event_enable  = 1'b1; //((current_state == S06_DOOR_OPEN) | (current_state == S07_DOOR_CLOSE)) ? 1'b1 : 1'b0;


  //---- STATE TRANSITION FOR DOOR EVENT --------------------------------------------------//
    
  // State transition
  defparam ST_uic_door_event_i.TW = 4;
  StateTransition ST_uic_door_event_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done  
    .enable(uic_door_event_enable),           // Enable toggle
    .triggerEn(con_door_status),              // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(event_command),            // Command
    .sequenceEn(seq_en_door_event),           // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR DOOR EVENT ----------------------------------------------//
  
  
//------------ OPEN/CLOSE EVENT -----------------------------------------------------------//  
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//------------ SET DIAL TEMP --------------------------------------------------------------//
    
  // State transition
  defparam ST_uic_set_temp_i.TW = 1;
  StateTransition ST_uic_set_temp_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done  
    .enable(1'b1),                            // Enable toggle
    .triggerEn(uic_command_reg[2]),           // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_set_temp),             // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );

//------------ END SET DIAL TEMP ----------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//------------ PRE-PRIME ------------------------------------------------------------------//

  // Pre Prime Enable based on state to run once
  assign uic_pre_prime_enable  = (current_state == S05_CMD_RDY) ? 1'b1 : 1'b0;
  
  // Prepare to prime if either  a blood or dialysate prime command
  assign uic_pre_prime_trigger = uic_command_reg[3] | uic_command_reg[4];
  
  //---- STATE TRANSITION PRE-PRIME INITIALIZE --------------------------------------------//
   
  // State transition
  defparam ST_uic_pre_prime_i.TW = 1;
  StateTransition ST_uic_pre_prime_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done  
    .enable(uic_pre_prime_enable),            // Enable toggle
    .triggerEn(uic_pre_prime_trigger),        // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(uic_pre_prime_cmd),        // Command
    .sequenceEn(seq_en_prime_init),           // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION PRE-PRIME INITIALIZE ----------------------------------------//

//------------ END PRE-PRIME --------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

  
//-----------------------------------------------------------------------------------------//
//------------ PRIME ----------------------------------------------------------------------//  
 
  //---- STATE TRANSITION FOR BLOOD PRIME--------------------------------------------------//

  // Enable transition based on current state
  assign uic_bp_prime_enable    = (current_state == S09_PRIME) ? 1'b1 : 1'b0;
   
  // Trigger and continuous run unless paused
  assign uic_bp_prime_trigger   = uic_command_reg[3] & ~uic_command_reg[5];
   
  // State transition
  defparam ST_uic_blood_prime_i.TW = 1;
  StateTransition ST_uic_blood_prime_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_bp_prime_enable),             // Enable toggle
    .triggerEn(uic_bp_prime_trigger),         // Signal to trigger state transition
    .forcedEn(uic_bp_prime_trigger),          // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_bp_prime),             // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR PRIME----------------------------------------------------//


  //---- STATE TRANSITION FOR DIALYSATE PRIME----------------------------------------------//

  // Enable transition based on current state
  assign uic_dp_prime_enable    = ((current_state == S09_PRIME) | (current_state == S13_BLOOD_RECIRC)) ? 1'b1 : 1'b0;
  
  // Trigger and continuous run unless paused
  assign uic_dp_prime_trigger   = uic_command_reg[4] & ~uic_command_reg[6];  
  
  // State transition 
  defparam ST_uic_dial_prime_i.TW = 1;
  StateTransition ST_uic_dial_prime_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_dp_prime_enable),             // Enable toggle
    .triggerEn(uic_dp_prime_trigger),         // Signal to trigger state transition
    .forcedEn(ioc_dprime_en),                 // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_dp_prime),             // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR DIALYSATE PRIME------------------------------------------//
  
  //---- STATE TRANSITION FOR PAUSE BLOOD PRIME--------------------------------------------//

  // Enable transition based on current state
  assign uic_bp_prime_pause_enable    = (current_state == S09_PRIME) ? 1'b1 : 1'b0;
    
  // State transition
  defparam ST_uic_blood_pause_prime_i.TW = 1;
  StateTransition ST_uic_blood_pause_prime_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_bp_prime_pause_enable),       // Enable toggle
    .triggerEn(uic_command_reg[5]),           // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_bp_pause_prime),       // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR PAUSE BLOOD PRIME ----------------------------------------//

  //---- STATE TRANSITION FOR PAUSE DIALYSATE PRIME ----------------------------------------//

  // Enable transition based on current state
  assign uic_dp_prime_pause_enable    = ((current_state == S09_PRIME) | (current_state == S13_BLOOD_RECIRC)) ? 1'b1 : 1'b0;
  
  // State transition 
  defparam ST_uic_dial_pause_prime_i.TW = 1;
  StateTransition ST_uic_dial_pause_prime_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_dp_prime_pause_enable),       // Enable toggle
    .triggerEn(uic_command_reg[6]),           // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_dp_pause_prime),       // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR PAUSE DIALYSATE PRIME------------------------------------//  

  //---- STATE TRANSITION FOR BPRIME DONE --------------------------------------------------//

  // Enable transition based on current state
  assign uic_bprime_done_enable   = (current_state == S09_PRIME) ? 1'b1 : 1'b0;
  
  // State transition 
  defparam ST_uic_bprime_done_i.TW = 1;
  StateTransition ST_uic_bprime_done_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_bprime_done_enable),          // Enable toggle
    .triggerEn(ioc_bprime_done),              // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(prime_done_cmd),           // Command
    .sequenceEn(seq_en_bprime_done),          // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR BPRIME DONE ----------------------------------------------//  
    
//------------ END PRIME ------------------------------------------------------------------//   
//-----------------------------------------------------------------------------------------//  



//-----------------------------------------------------------------------------------------// 
//------------ RE-PRIME -------------------------------------------------------------------// 

  //---- STATE TRANSITION FOR RE-PRIME ----------------------------------------------------//

  // Enable transition based on current state
  assign uic_reprime_enable    = (current_state == S11_RE_PRIME_OR_CIRC) ? 1'b1 : 1'b0;
  assign uic_reprime_trigger   = uic_command_reg[10] & ~uic_command_reg[11];
  
  // State transition 
  defparam ST_uic_reprime_i.TW = 1;
  StateTransition ST_uic_reprime_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_reprime_enable),              // Enable toggle
    .triggerEn(uic_reprime_trigger),          // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(blood_reprime_cmd),        // Command
    .sequenceEn(seq_en_reprime),              // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR RE-PRIME ----------------------------------------------//


  //---- STATE TRANSITION FOR STOP RE-PRIME ---------------------------------------------//

  // Enable transition based on current state
  assign uic_reprime_done_enable    = (current_state == S12_BLOOD_REPRIME) ? 1'b1 : 1'b0;
    
  // State transition 
  defparam ST_uic_reprime_done_i.TW = 1;
  StateTransition ST_uic_reprime_done_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_reprime_done_enable),         // Enable toggle
    .triggerEn(uic_command_reg[11]),          // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(reprime_done_cmd),         // Command
    .sequenceEn(seq_en_reprime_done),         // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR STOP RE-PRIME -------------------------------------------//


//------------ END RE-PRIME ---------------------------------------------------------------// 
//-----------------------------------------------------------------------------------------// 


//-----------------------------------------------------------------------------------------// 
//------------ RE-CIRC --------------------------------------------------------------------// 

  //---- STATE TRANSITION FOR RE-CIRC -----------------------------------------------------//

  // Enable transition based on current state
  assign uic_recirc_enable    = (current_state == S11_RE_PRIME_OR_CIRC) ? 1'b1 : 1'b0;
  assign uic_recirc_trigger   = uic_command_reg[7] & ~(uic_command_reg[8] | uic_command_reg[9]);
  
  // State transition 
  defparam ST_uic_recirc_i.TW = 1;
  StateTransition ST_uic_recirc_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_recirc_enable),               // Enable toggle
    .triggerEn(uic_recirc_trigger),           // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(blood_recirc_cmd),         // Command
    .sequenceEn(seq_en_recirc),               // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR RE-CIRC --------------------------------------------------//
  
  
  //---- STATE TRANSITION FOR DPRIME DONE --------------------------------------------------//

  // Enable transition based on current state
  assign uic_dprime_done_enable    = (current_state == S13_BLOOD_RECIRC) ? 1'b1 : 1'b0;
  
  // State transition 
  defparam ST_uic_dprime_done_i.TW = 1;
  StateTransition ST_uic_dprime_done_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_dprime_done_enable),          // Enable toggle
    .triggerEn(ioc_dprime_done),              // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(recirc_done_cmd),          // Command
    .sequenceEn(seq_en_dprime_done),          // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR DPRIME DONE ---------------------------------------------//  
    
//------------ END RE-CIRC ----------------------------------------------------------------// 
//-----------------------------------------------------------------------------------------// 


//-----------------------------------------------------------------------------------------// 
//------------ START ALARMS TEST ----------------------------------------------------------// 

  //---- STATE TRANSITION FOR ALARMS TEST -------------------------------------------------//

  // Enable transition based on current state
  assign uic_start_alarms_enable    = (current_state == S14_START_ALARMS) ? 1'b1 : 1'b0;
  assign uic_start_alarms_trigger   = uic_command_reg[13];
  
  // State transition 
  defparam ST_uic_alarms_i.TW = 1;
  StateTransition ST_uic_alarms_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_start_alarms_enable),         // Enable toggle
    .triggerEn(uic_start_alarms_trigger),     // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(start_alarms_cmd),         // Command
    .sequenceEn(),                            // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALARMS TEST --------------------------------------------//


  //---- STATE TRANSITION FOR ALARM PRESSURE TEST ----------------------------------------//

  // Enable transition based on current state
  assign uic_alarm_pressure_enable    = (current_state == S15_ALARM_PRESSURE) ? 1'b1 : 1'b0;
  assign uic_alarm_pressure_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_alarm_pressure_i.TW = 1;
  StateTransition ST_uic_alarm_pressure_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_alarm_pressure_enable),       // Enable toggle
    .triggerEn(uic_alarm_pressure_trigger),   // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(alarm_pressure_done_cmd),  // Command
    .sequenceEn(seq_en_alarm_pressure),       // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALARM PRESSURE TEST -----------------------------------//

  //---- STATE TRANSITION FOR ALARM AIR BUBBLE TEST -------------------------------------//

  // Enable transition based on current state
  assign uic_alarm_air_bubble_enable    = (current_state == S17_ALARM_AIRBUBBLE) ? 1'b1 : 1'b0;
  assign uic_alarm_air_bubble_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_alarm_airbubble_i.TW = 1;
  StateTransition ST_uic_alarm_airbubble_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_alarm_air_bubble_enable),     // Enable toggle
    .triggerEn(uic_alarm_air_bubble_trigger), // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(alarm_air_bubble_done_cmd),// Command
    .sequenceEn(seq_en_alarm_air_bubble),     // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR AIR BUBBLE TEST ------------------------------------//

  //---- STATE TRANSITION FOR ALARM BLOOD LEAK TEST ---------------------------------//

  // Enable transition based on current state
  assign uic_alarm_blood_leak_enable    = (current_state == S19_ALARM_BLOODLEAK) ? 1'b1 : 1'b0;
  assign uic_alarm_blood_leak_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_alarm_blood_leak_i.TW = 1;
  StateTransition ST_uic_alarm_blood_leak_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_alarm_blood_leak_enable),     // Enable toggle
    .triggerEn(uic_alarm_blood_leak_trigger), // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(alarm_blood_leak_done_cmd),// Command
    .sequenceEn(seq_en_alarm_blood_leak),     // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR BLOOD LEAK TEST ------------------------------------//


  //---- STATE TRANSITION FOR ALARM AMMONIA TEST -------------------------------------//

  // Enable transition based on current state
  assign uic_alarm_ammonia_enable    = (current_state == S21_ALARM_AMMONIA) ? 1'b1 : 1'b0;
  assign uic_alarm_ammonia_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_alarm_ammonia_i.TW = 1;
  StateTransition ST_uic_alarm_ammonia_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_alarm_ammonia_enable),        // Enable toggle
    .triggerEn(uic_alarm_ammonia_trigger),    // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(alarm_ammonia_done_cmd),   // Command
    .sequenceEn(seq_en_alarm_ammonia),        // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR AMMONIA TEST ---------------------------------------//

  //---- STATE TRANSITION FOR ALARM ELECTROLYTE TEST ---------------------------------//

  // Enable transition based on current state
  assign uic_alarm_electrolyte_enable    = (current_state == S23_ALARM_ELECTROLYTE) ? 1'b1 : 1'b0;
  assign uic_alarm_electrolyte_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_alarm_electrolyte_i.TW = 1;
  StateTransition ST_uic_alarm_electrolyte_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_alarm_electrolyte_enable),      // Enable toggle
    .triggerEn(uic_alarm_electrolyte_trigger),  // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(alarm_electrolyte_done_cmd), // Command
    .sequenceEn(seq_en_alarm_electrolyte),      // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ELECTROLYTE TEST -----------------------------------//

  //---- STATE TRANSITION FOR ALARM TEMP TEST ----------------------------------------//

  // Enable transition based on current state
  assign uic_alarm_temp_enable    = (current_state == S25_ALARM_TEMP) ? 1'b1 : 1'b0;
  assign uic_alarm_temp_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_alarm_temp_i.TW = 1;
  StateTransition ST_uic_alarm_temp_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_alarm_temp_enable),             // Enable toggle
    .triggerEn(uic_alarm_temp_trigger),         // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(alarm_temp_done_cmd),        // Command
    .sequenceEn(seq_en_alarm_temp),             // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR TEMP TEST -----------------------------------------//

//------------ END ALARMS TEST -------------------------------------------------------// 
//------------------------------------------------------------------------------------// 

//------------------------------------------------------------------------------------//
//------------ GET DIALYSATE TEMP ----------------------------------------------------//


  //---- STATE TRANSITION FOR GET DIALYSATE TEMP -------------------------------------//

  // Enable transition based on current state
  assign uic_dial_temp_enable    = (current_state == S27_GET_DIAL_TEMP) ? 1'b1 : 1'b0;
  assign uic_dial_temp_trigger   = 1'b1;
  
  // State transition 
  defparam ST_uic_dial_temp_i.TW = 1;
  StateTransition ST_uic_dial_temp_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_dial_temp_enable),              // Enable toggle
    .triggerEn(uic_dial_temp_trigger),          // Signal to trigger state transition
    .forcedEn(uic_dial_temp_enable),            // Signal to force enable
    .transitionCmd(),                           // Command
    .sequenceEn(seq_en_dial_temp),              // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR GET DIALYSATE TEMP ---------------------------------//

  //---- STATE TRANSITION FOR STOP RE-CIRC -------------------------------------------------//

  // Enable transition based on current state
  assign uic_recirc_done_enable    = (current_state == S27_GET_DIAL_TEMP) ? 1'b1 : 1'b0;  
  assign uic_recirc_done_trigger   = uic_command_reg[8] | uic_command_reg[9];
  
  // State transition 
  defparam ST_uic_recirc_done_i.TW = 1;
  StateTransition ST_uic_recirc_done_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_recirc_done_enable),          // Enable toggle
    .triggerEn(uic_recirc_done_trigger),      // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(stop_recirc_cmd),          // Command
    .sequenceEn(seq_en_recirc_done),          // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR RECIRC DONE ----------------------------------------------//


//------------ END GET DIALYSATE TEMP ------------------------------------------------------// 
//------------------------------------------------------------------------------------------// 

//------------------------------------------------------------------------------------------//
//------------ BLOOD FLUSH -----------------------------------------------------------------//

  //---- STATE TRANSITION FOR BLOOD FLUSH CMD    -------------------------------------------//

  // Enable transition based on current state
  assign uic_blood_flush_enable    = (current_state == S28_BLOOD_FLUSH) ? 1'b1 : 1'b0;
  assign uic_blood_flush_trigger   = uic_command_reg[14] & ~(uic_command_reg[15] | uic_command_reg[16]);
  
  // State transition 
  defparam ST_uic_blood_flush_i.TW = 1;
  StateTransition ST_uic_blood_flush_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_blood_flush_enable),            // Enable toggle
    .triggerEn(uic_blood_flush_trigger),        // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(blood_flush_done_cmd),       // Command
    .sequenceEn(seq_en_blood_flush),            // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR BLOOD FLUSH  --------------------------------------------//


  //---- STATE TRANSITION FOR BLOOD FLUSH STOP CMD    -------------------------------------//

  // Enable transition based on current state
  assign uic_blood_flush_stop_enable    = (current_state == S28_BLOOD_FLUSH) ? 1'b1 : 1'b0;
  assign uic_blood_flush_stop_trigger   = uic_command_reg[15] | uic_command_reg[16];
  
  // State transition 
  defparam ST_uic_blood_flush_stop_i.TW = 1;
  StateTransition ST_uic_blood_flush_stop_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_blood_flush_stop_enable),       // Enable toggle
    .triggerEn(uic_blood_flush_stop_trigger),   // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(),                           // Command
    .sequenceEn(seq_en_blood_flush_stop),       // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR BLOOD FLUSH STOP CMD ------------------------------------//


//------------ END BLOOD FLUSH ------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//


//-----------------------------------------------------------------------------------------//
//------------ TREATMENT ------------------------------------------------------------------//

  //---- STATE TRANSITION FOR TREATMENT INITIALIZE ----------------------------------------//

  // Enable transition based on current state
  assign uic_treatment_init_enable    = (current_state == S29_TREATMENT_WAIT) ? 1'b1 : 1'b0;
  assign uic_treatment_init_trigger   = uic_command_reg[17];  
  
  // State transition 
  defparam ST_uic_treatment_init_i.TW = 1;
  StateTransition ST_uic_treatment_init_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_treatment_init_enable),         // Enable toggle
    .triggerEn(uic_treatment_init_trigger),     // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(treatment_cmd),              // Command
    .sequenceEn(seq_en_treatment_init),         // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR TREATMENT INITIALIZE ------------------------------------//


  //---- STATE TRANSITION FOR TREATMENT ---------------------------------------------------//

  // Enable transition based on current state
  assign uic_treatment_enable    = (current_state == S30_TREATMENT) ? 1'b1 : 1'b0;
  assign uic_treatment_trigger   = (uic_command_reg[17] | uic_command_reg[21]) & ~uic_command_reg[19];  
  assign uic_treatment_forced    = ioc_treatment_en & uic_treatment_enable;
  
  // State transition 
  defparam ST_uic_treatment_i.TW = 1;
  StateTransition ST_uic_treatment_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_treatment_enable),              // Enable toggle
    .triggerEn(uic_treatment_trigger),          // Signal to trigger state transition
    .forcedEn(uic_treatment_forced),            // Signal to force enable
    .transitionCmd(),                           // Command
    .sequenceEn(seq_en_treatment),              // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR TREATMENT -----------------------------------------------//

  //---- STATE TRANSITION FOR TREATMENT PAUSE ---------------------------------------------//

  // Enable transition based on current state
  assign uic_treatment_pause_enable    = (current_state == S30_TREATMENT) ? 1'b1 : 1'b0;
  assign uic_treatment_pause_trigger   = uic_command_reg[19];   
  
  // State transition 
  defparam ST_uic_treatment_pause_i.TW = 1;
  StateTransition ST_uic_treatment_pause_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_treatment_pause_enable),        // Enable toggle
    .triggerEn(uic_treatment_pause_trigger),    // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(treatment_stop_cmd),         // Command
    .sequenceEn(seq_en_treatment_paused),       // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR TREATMENT PAUSE -----------------------------------------//    
    
  //---- STATE TRANSITION FOR TREATMENT DONE ---------------------------------------------//

  // Enable transition based on current state
  assign uic_treatment_done_enable    = (current_state == S30_TREATMENT) ? 1'b1 : 1'b0;
  assign uic_treatment_done_trigger   = ioc_treatment_done | uic_command_reg[20];   
  
  // State transition 
  defparam ST_uic_treatment_done_i.TW = 1;
  StateTransition ST_uic_treatment_done_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_treatment_done_enable),         // Enable toggle
    .triggerEn(uic_treatment_done_trigger),     // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(treatment_done_cmd),         // Command
    .sequenceEn(seq_en_treatment_finished),     // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR TREATMENT DONE ------------------------------------------//

  assign seq_en_treatment_done = seq_en_treatment_finished;

  //---- STATE TRANSITION FOR TREATMENT STOPPED -------------------------------------------//

  // Enable transition based on current state
  assign uic_treatment_stopped_enable    = (current_state == S32_TREATMENT_DONE) ? 1'b1 : 1'b0;
  assign uic_treatment_stopped_trigger   = 1'b1;   
  
  // State transition 
  defparam ST_uic_treatment_stopped_i.TW = 1;
  StateTransition ST_uic_treatment_stopped_i
  (
    .clk(clk),                                  // System clock
    .reset(reset),                              // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),                // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),    // Strobe that indicates sequence list is done
    .enable(uic_treatment_stopped_enable),      // Enable toggle
    .triggerEn(uic_treatment_stopped_trigger),  // Signal to trigger state transition
    .forcedEn(1'b0),                            // Signal to force enable
    .transitionCmd(treatment_stopped_cmd),      // Command
    .sequenceEn(seq_en_treatment_stopped),      // Sequence Enable
    .seq_serviced_strb()                        // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR TREATMENT STOPPED ---------------------------------------//


//------------ END TREATMENT --------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

//-----------------------------------------------------------------------------------------//
//------------ RINSE ----------------------------------------------------------------------//
 
  
  //---- STATE TRANSITION FOR RINSE ----------------------------------------------------//

  // Enable transition based on current state
  assign uic_rinse_enable    = (current_state == S35_RINSEBACK) ? 1'b1 : 1'b0;
  assign uic_rinse_trigger   = uic_command_reg[25] & ~uic_command_reg[26];
  assign uic_rinse_force     = ioc_rinse_en & ~uic_command_reg[26];
  
  // State transition 
  defparam ST_uic_rinse_i.TW = 1;
  StateTransition ST_uic_rinse_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_rinse_enable),                // Enable toggle
    .triggerEn(uic_rinse_trigger),            // Signal to trigger state transition
    .forcedEn(uic_rinse_force),               // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_rinse),                // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR RINSE -------------------------------------------------//


  //---- STATE TRANSITION FOR RINSE PAUSE -----------------------------------------------//

  // Enable transition based on current state
  assign uic_rinse_pause_enable    = (current_state == S35_RINSEBACK) ? 1'b1 : 1'b0;
  assign uic_rinse_pause_trigger   = uic_command_reg[26];
  
  // State transition 
  defparam ST_uic_rinse_pause_i.TW = 1;
  StateTransition ST_uic_rinse_pause_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_rinse_pause_enable),          // Enable toggle
    .triggerEn(uic_rinse_pause_trigger),      // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_rinse_pause),          // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR RINSE PAUSE ---------------------------------------------// 

  //---- STATE TRANSITION FOR RINSE DONE --------------------------------------------------//

  // Enable transition based on current state
  assign uic_rinse_done_enable    = (current_state == S35_RINSEBACK) ? 1'b1 : 1'b0;
  assign uic_rinse_done_trigger   = ioc_rinse_done;
  
  // State transition 
  defparam ST_uic_rinse_done_i.TW = 1;
  StateTransition ST_uic_rinse_done_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_rinse_done_enable),           // Enable toggle
    .triggerEn(uic_rinse_done_trigger),       // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(rinse_done_cmd),           // Command
    .sequenceEn(seq_en_rinse_done),           // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR RINSE DONE ---------------------------------------------//   
  
  
//------------ END RINSE ------------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//


//-----------------------------------------------------------------------------------------//
//------------ EMPTY ----------------------------------------------------------------------//
  
  //---- STATE TRANSITION FOR EMPTY -------------------------------------------------------//

  // Enable transition based on current state
  assign uic_empty_enable    = ((current_state == S38_EMPTY) | (current_state == S39_TREATMENT_OVER)) ? 1'b1 : 1'b0;
  assign uic_empty_trigger   = uic_command_reg[27] & ~uic_command_reg[28];
  assign uic_empty_force     = ioc_empty_en & ~uic_command_reg[28];
  
  // State transition 
  defparam ST_uic_empty_i.TW = 1;
  StateTransition ST_uic_empty_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_empty_enable),                // Enable toggle
    .triggerEn(uic_empty_trigger),            // Signal to trigger state transition
    .forcedEn(uic_empty_force),               // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_empty),                // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR EMPTY --------------------------------------------------//


  //---- STATE TRANSITION FOR EMPTY STOP -------------------------------------------------//

  // Enable transition based on current state
  assign uic_empty_stop_enable    = ((current_state == S38_EMPTY) | (current_state == S39_TREATMENT_OVER)) ? 1'b1 : 1'b0;
  assign uic_empty_stop_trigger   = uic_command_reg[28];
  
  // State transition 
  defparam ST_uic_empty_stop_i.TW = 1;
  StateTransition ST_uic_empty_stop_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(uic_empty_stop_enable),           // Enable toggle
    .triggerEn(uic_empty_stop_trigger),       // Signal to trigger state transition
    .forcedEn(1'b0),                          // Signal to force enable
    .transitionCmd(empty_done_cmd),           // Command
    .sequenceEn(seq_en_empty_stop),           // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR EMPTY STOP ----------------------------------------------//  
    
  assign seq_en_stop_all = seq_en_empty_stop | estop_pressed;
  
//------------ END EMPTY ------------------------------------------------------------------//
//-----------------------------------------------------------------------------------------//

//  localparam A00_NORMAL              = 4'h0;
//  localparam A01_DETECTION_01        = 4'h1;
//  localparam A02_DETECTION_02        = 4'h2;
//  localparam A03_DETECTION_03        = 4'h3;
//  localparam A04_ALARM               = 4'h4;  
//  localparam A05_ALERT               = 4'h5;  
//  localparam A06_RESUME_ALARM        = 4'h6;  
//  localparam A07_RESUME_ALERT        = 4'h7;  
//  localparam A08_RESUME_SYNC1        = 4'h8;
//  localparam A09_RESUME_SYNC2        = 4'h9;
//  localparam A10_RESUME_SYNC3        = 4'ha;
//  localparam A11_RESUME_SYNC4        = 4'hb;
//  localparam A12_SHUTDOWN            = 4'hc;


  //Syncronous state from system timer strobe
  always@(posedge clk)
  begin
    if (reset)
      current_alarm_state <= A00_NORMAL;
    else if (sys_tmr_strb)
      current_alarm_state <= next_alarm_state;
  end  
  
  //State transitions
  always@(current_alarm_state,alarm_alert_detected,alarm_detected,alert_detected,resume_alarm,resume_alert,permanent_shutdown)
  begin
    case (current_alarm_state)
      
      A00_NORMAL        :   if (alarm_alert_detected)
                              next_alarm_state <= A01_DETECTION_01;
                            else
                              next_alarm_state <= A00_NORMAL;
                                  
      A01_DETECTION_01  :     next_alarm_state <= A02_DETECTION_02;
      
      A02_DETECTION_02  :     next_alarm_state <= A03_DETECTION_03;
      
      A03_DETECTION_03  :   if (alarm_detected)
                              next_alarm_state <= A04_ALARM;
                            else if (alert_detected)
                              next_alarm_state <= A05_ALERT;
                            else
                              next_alarm_state <= A07_RESUME_ALERT;

      A04_ALARM         :   if (resume_alarm)
                              next_alarm_state <= A06_RESUME_ALARM;
                            else if (permanent_shutdown)
                              next_alarm_state <= A12_SHUTDOWN;
                            else
                              next_alarm_state <= A04_ALARM;
                              
      A05_ALERT         :   if (resume_alert)
                              next_alarm_state <= A07_RESUME_ALERT;
                            else
                              next_alarm_state <= A05_ALERT;

      A06_RESUME_ALARM  :     next_alarm_state <= A08_RESUME_SYNC1; 
                                  
      A07_RESUME_ALERT  :     next_alarm_state <= A08_RESUME_SYNC1;
      
      A08_RESUME_SYNC1  :     next_alarm_state <= A09_RESUME_SYNC2;
      
      A09_RESUME_SYNC2  :     next_alarm_state <= A10_RESUME_SYNC3;
      
      A10_RESUME_SYNC3  :     next_alarm_state <= A11_RESUME_SYNC4;
      
      A11_RESUME_SYNC4  :     next_alarm_state <= A00_NORMAL;
                                  
      A12_SHUTDOWN      :     next_alarm_state <= A12_SHUTDOWN;
      
      default           :     next_alarm_state <= A00_NORMAL;
    endcase
  end
   
//  //Syncronous state
//  always@(posedge clk)
//  begin
//    if (reset) begin
//        last_alarm_state    <= A00_NORMAL;
//        last_alarm_state_Z1 <= A00_NORMAL;
//    end else begin
//        last_alarm_state    <= current_alarm_state;
//        last_alarm_state_Z1 <= last_alarm_state;
//    end
//  end  
//
//  // State change strobe
//  always@(posedge clk)
//  begin
//    if (reset)
//      change_alarm_strb <= 1'b0;
//    else if (last_alarm_state_Z1 != last_alarm_state)
//      change_alarm_strb <= 1'b1;
//    else
//      change_alarm_strb <= 1'b0;
//  end

  // Detect Change in alarms
  always@(posedge clk)
  begin
    if (reset)
      alarm_detected <= 1'b0;
    else if (saf_alarms[17:0] != 18'h00000)
      alarm_detected <= 1'b1;
    else  
      alarm_detected <= 1'b0;
  end                               

  // Detect Alarm
  always@(posedge clk)
  begin
    if (reset)
      alert_detected <= 1'b0;
    else if (saf_alarms[35:18] != 18'h00000)
      alert_detected <= 1'b1;
    else  
      alert_detected <= 1'b0;
  end 
  
  // Transition if alarm or alert
  assign alarm_alert_detected = alarm_detected | alert_detected;
  
  // Enable System States                       
  // Disable control state machine. Allow Alarm handling and register updates and syncronization
  // Enable empty, stop all and door event
  always@(posedge clk)
  begin
    if (reset)
      sys_state_enabled <= {LS{1'b1}};
    else if (alarm_alert_detected || permanent_shutdown)
      sys_state_enabled <= 64'hFFFFFFFC0000003F;
    else if (current_alarm_state == A00_NORMAL)
      sys_state_enabled <= {LS{1'b1}};
  end 
  
  // Transition state based on alarm status
  assign resume_alarm = saf_alarm_status[0];
  assign resume_alert = saf_alarm_status[1];
  assign sys_shutdown = saf_alarm_status[2]; 
  
  //Capture fatal shutdown
  always@(posedge clk)
  begin
    if (reset)
      permanent_shutdown <= 1'b0;  
    else if (sys_shutdown)
      permanent_shutdown <= 1'b1;
  end  
  
  //---- STATE TRANSITION FOR MONITOR READY -----------------------------------------------//

  // Enable transition based on current state
  assign monitor_ready_enable    = (current_alarm_state == A00_NORMAL) ? 1'b1 : 1'b0;
  assign monitor_ready_trigger   = 1'b0;
  assign monitor_ready_force     = monitor_ready_enable;
  
  // State transition 
  defparam ST_monitor_ready_i.TW = 1;
  StateTransition ST_monitor_ready_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(monitor_ready_enable),            // Enable toggle
    .triggerEn(monitor_ready_trigger),        // Signal to trigger state transition
    .forcedEn(monitor_ready_force),           // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_monitor_ready),        // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR MONITOR READY ------------------------------------------//  

  //---- STATE TRANSITION FOR ALARM DETECT ------------------------------------------------//

  // Enable transition based on current state
  assign alarm_detect_enable    = (current_alarm_state == A03_DETECTION_03) ? 1'b1 : 1'b0;
  assign alarm_detect_trigger   = 1'b0;
  assign alarm_detect_force     = alarm_detect_enable & alarm_detected;
  
  // State transition 
  defparam ST_alarm_detect_i.TW = 1;
  StateTransition ST_alarm_detect_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(alarm_detect_enable),             // Enable toggle
    .triggerEn(alarm_detect_trigger),         // Signal to trigger state transition
    .forcedEn(alarm_detect_force),            // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_alarm_setup),          // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALARM DETECT -------------------------------------------// 

  
  //---- STATE TRANSITION FOR ALERT DETECT -----------------------------------------------//

  // Enable transition based on current state
  assign alert_detect_enable    = (current_alarm_state == A03_DETECTION_03) ? 1'b1 : 1'b0;
  assign alert_detect_trigger   = 1'b0;
  assign alert_detect_force     = alert_detect_enable & alert_detected & ~alarm_detected;
  
  // State transition 
  defparam ST_alert_detect_i.TW = 1;
  StateTransition ST_alert_detect_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(alert_detect_enable),             // Enable toggle
    .triggerEn(alert_detect_trigger),         // Signal to trigger state transition
    .forcedEn(alert_detect_force),            // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_alert_setup),          // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALERT DETECT ------------------------------------------//         

  //---- STATE TRANSITION FOR ALARM -----------------------------------------------------//

  // Enable transition based on current state
  assign alarm_handle_enable    = (current_alarm_state == A04_ALARM) ? 1'b1 : 1'b0;
  assign alarm_handle_trigger   = 1'b1;
  assign alarm_handle_force     = alarm_handle_enable;
  
  // State transition 
  defparam ST_alarm_handle_i.TW = 1;
  StateTransition ST_alarm_handle_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(alarm_handle_enable),             // Enable toggle
    .triggerEn(alarm_handle_trigger),         // Signal to trigger state transition
    .forcedEn(alarm_handle_force),            // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_alarm_handle),         // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALARM -------------------------------------------------//       
  
  //---- STATE TRANSITION FOR ALERT -----------------------------------------------------//

  // Enable transition based on current state
  assign alert_handle_enable    = (current_alarm_state == A05_ALERT) ? 1'b1 : 1'b0;
  assign alert_handle_trigger   = 1'b1;
  assign alert_handle_force     = alert_handle_enable;
  
  // State transition 
  defparam ST_alert_handle_i.TW = 1;
  StateTransition ST_alert_handle_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(alert_handle_enable),             // Enable toggle
    .triggerEn(alert_handle_trigger),         // Signal to trigger state transition
    .forcedEn(alert_handle_force),            // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_alert_handle),         // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALERT ----------------------------------------------//      
    
  //---- STATE TRANSITION FOR ALARM RESUME -------------------------------------------//

  // Enable transition based on current state
  assign alarm_resume_enable    = (current_alarm_state == A06_RESUME_ALARM) ? 1'b1 : 1'b0;
  assign alarm_resume_trigger   = 1'b1;
  assign alarm_resume_force     = alarm_resume_enable;
  
  // State transition 
  defparam ST_alarm_resume_i.TW = 1;
  StateTransition ST_alarm_resume_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(alarm_resume_enable),             // Enable toggle
    .triggerEn(alarm_resume_trigger),         // Signal to trigger state transition
    .forcedEn(alarm_resume_force),            // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_alarm_resume),         // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALARM RESUME ---------------------------------------//       
  
  //---- STATE TRANSITION FOR ALERT RESUME -------------------------------------------//

  // Enable transition based on current state
  assign alert_resume_enable    = (current_alarm_state == A07_RESUME_ALERT) ? 1'b1 : 1'b0;
  assign alert_resume_trigger   = 1'b1;
  assign alert_resume_force     = alert_resume_enable;
  
  // State transition 
  defparam ST_alert_resume_i.TW = 1;
  StateTransition ST_alert_resume_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(alert_resume_enable),             // Enable toggle
    .triggerEn(alert_resume_trigger),         // Signal to trigger state transition
    .forcedEn(alert_resume_force),            // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_alert_resume),         // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR ALERT RESUME ---------------------------------------//     

  //---- STATE TRANSITION FOR FATAL ALARM --------------------------------------------//

  // Enable transition based on current state
  assign shutdown_enable    = (current_alarm_state == A12_SHUTDOWN) ? 1'b1 : 1'b0;
  assign shutdown_trigger   = 1'b1;
  assign shutdown_force     = shutdown_enable;
  
  // State transition 
  defparam ST_shutdown_i.TW = 1;
  StateTransition ST_shutdown_i
  (
    .clk(clk),                                // System clock
    .reset(reset),                            // System reset (Syncronous)
    .sys_tmr_strb(sys_tmr_strb),              // System timer strobe 
    .seq_list_done_strb(seq_list_done_strb),  // Strobe that indicates sequence list is done
    .enable(shutdown_enable),                 // Enable toggle
    .triggerEn(shutdown_trigger),             // Signal to trigger state transition
    .forcedEn(shutdown_force),                // Signal to force enable
    .transitionCmd(),                         // Command
    .sequenceEn(seq_en_shutdown),             // Sequence Enable
    .seq_serviced_strb()                      // Sequence Serviced
  );
  
  //---- END STATE TRANSITION FOR FATAL ALARM --------------------------------------//     
    

  // OUTPUT {Syncronized to sys_timer and done strobes} 
  // Create the sequence list enables based on individual sequence enables
  //   
  assign seq_list_bits[0]   = 1'b1;                     // 1 Frame Syncronization Sequence
  assign seq_list_bits[1]   = seq_en_initialize;        // 2 Initialize PUC Motors  
  assign seq_list_bits[2]   = seq_en_open_door;         // 3 Open the door
  assign seq_list_bits[3]   = seq_en_close_door;        // 4 Close the door
  assign seq_list_bits[4]   = seq_en_door_event;        // 5 Door Changed Position Event
  assign seq_list_bits[5]   = seq_en_reg_update;        // 6 Update register info between FPGA's
  assign seq_list_bits[6]   = seq_en_prime_init;        // 7 Initialize counters for prime
  assign seq_list_bits[7]   = seq_en_set_temp;          // 8 Set the dialysate temperature
  assign seq_list_bits[8]   = seq_en_bp_prime;          // 9 Blood Side Prime
  assign seq_list_bits[9]   = seq_en_dp_prime;          // 10 Dialysate Side Prime
  assign seq_list_bits[10]  = seq_en_bp_pause_prime;    // 11 Blood Side Prime Pause
  assign seq_list_bits[11]  = seq_en_dp_pause_prime;    // 12 Dialysate Side Prime Pause
  assign seq_list_bits[12]  = seq_en_bprime_done;       // 13 Wrap up prime operation blood done
  assign seq_list_bits[13]  = seq_en_dprime_done;       // 14 Wrap up prime operation dial done
  assign seq_list_bits[14]  = seq_en_reprime;           // 15 Re prime start motor in same direction
  assign seq_list_bits[15]  = seq_en_reprime_done;      // 16 Stop re-prime
  assign seq_list_bits[16]  = seq_en_recirc;            // 17 Start Blood Pump in FWD direction
  assign seq_list_bits[17]  = seq_en_recirc_done;       // 18 Stop Blood Pump in FWD direction
  assign seq_list_bits[18]  = seq_en_alarm_pressure;    // 19 Pass Pressure Sensor Alarm
  assign seq_list_bits[19]  = seq_en_alarm_air_bubble;  // 20 Pass Air Bubble Alarm
  assign seq_list_bits[20]  = seq_en_alarm_blood_leak;  // 21 Pass Blood Leak Alarm
  assign seq_list_bits[21]  = seq_en_alarm_ammonia;     // 22 Pass Ammonia Alarm
  assign seq_list_bits[22]  = seq_en_alarm_electrolyte; // 23 Pass Electrolyte Alarm
  assign seq_list_bits[23]  = seq_en_alarm_temp;        // 24 Pass Temperature Alarm
  assign seq_list_bits[24]  = seq_en_treatment_init;    // 25 Treatment Initialize
  assign seq_list_bits[25]  = seq_en_treatment;         // 26 Treatment 
  assign seq_list_bits[26]  = seq_en_treatment_done;    // 27 Treatment Done
  assign seq_list_bits[27]  = seq_en_treatment_stopped; // 28 Treatment Stopped
  assign seq_list_bits[28]  = seq_en_dial_temp;         // 29 Get Dial Temp
  assign seq_list_bits[29]  = seq_en_blood_flush;       // 30 Blood Flush
  assign seq_list_bits[30]  = seq_en_blood_flush_stop;  // 31 Pause or Stop Blood Flush
  assign seq_list_bits[31]  = seq_en_rinse;             // 32 Rinseback
  assign seq_list_bits[32]  = seq_en_rinse_pause;       // 33 Stop Rinseback
  assign seq_list_bits[33]  = seq_en_rinse_done;        // 34 Rinseback done
  assign seq_list_bits[34]  = seq_en_empty;             // 35 Empty
  assign seq_list_bits[35]  = seq_en_stop_all;          // 36 Stop Empty
  
  assign seq_list_bits[36]  = seq_en_alarm_setup;       // 37 Set up Alarm Response 
  assign seq_list_bits[37]  = seq_en_alert_setup;       // 38 Set up Alert Response
  assign seq_list_bits[38]  = seq_en_alarm_handle;      // 39 Handle Alarms
  assign seq_list_bits[39]  = seq_en_alert_handle;      // 40 Handle Alerts 
  assign seq_list_bits[40]  = seq_en_alarm_resume;      // 41 Resume from Alarm
  assign seq_list_bits[41]  = seq_en_alert_resume;      // 42 Resume from Alert 
  assign seq_list_bits[42]  = seq_en_shutdown;          // 43 Shutdown 
  assign seq_list_bits[43]  = seq_en_monitor_ready;     // 44 Normal Operation
  assign seq_list_bits[44]  = seq_en_alarm_audio;       // 45 Listener for Audio Commands
  assign seq_list_bits[45]  = 1'b0;                     // 46
  assign seq_list_bits[46]  = 1'b0;                     // 47
  assign seq_list_bits[47]  = 1'b0;                     // 48
  assign seq_list_bits[48]  = 1'b0;                     // 49
  assign seq_list_bits[49]  = seq_en_treatment_paused;  // 50 TREATMENT PAUSE
  assign seq_list_bits[50]  = 1'b0;                     // 
  assign seq_list_bits[51]  = 1'b0;                     // 
  assign seq_list_bits[52]  = 1'b0;                     // 
  assign seq_list_bits[53]  = 1'b0;                     // 
  assign seq_list_bits[54]  = 1'b0;                     // 
  assign seq_list_bits[55]  = 1'b0;                     // 
  assign seq_list_bits[56]  = 1'b0;                     // 
  assign seq_list_bits[57]  = 1'b0;                     // 
  assign seq_list_bits[58]  = 1'b0;                     // 
  assign seq_list_bits[59]  = 1'b0;                     // 
  assign seq_list_bits[60]  = 1'b0;                     // 
  assign seq_list_bits[61]  = 1'b0;                     // 
  assign seq_list_bits[62]  = 1'b0;                     // 
  assign seq_list_bits[63]  = seq_en_por;               // 64 POR Initialize
  
  // Capture enable list for next
  always@(posedge clk)
  begin
    if (reset)
      seq_list_en <= {LS{1'b0}};
    else if (sys_tmr_strb_Z1)
      seq_list_en <= (seq_list_bits & sys_state_enabled);
  end
  
  // Debug vector
  always@(posedge clk)
  begin
    if (reset)
      state_debug <= 16'h0000;
    else
      state_debug <= {seq_list_done_strb, sys_tmr_strb, seq_list_en[13:6], current_state[5:0]};  
  end

  // IO State
  always@(posedge clk)
  begin
    if (reset)
      io_state <= 36'h000000000;
    else
      io_state <= {2'b00, seq_list_en[15:0], 12'h000, current_state[5:0]};  
  end  
  
  // Alarm State
  always@(posedge clk)
  begin
    if (reset)
      alarm_state <= 36'h000000000;
    else
      alarm_state <= {permanent_shutdown, saf_alarm_status[2:0], 12'h000, seq_list_en[43:36], 8'h00, current_alarm_state[3:0]};          
  end  
  
endmodule
