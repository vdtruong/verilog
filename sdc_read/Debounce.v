//-----------------------------------------------------------------
//  Module:     Debounce
//  Project:    
//  Version:    0.01-1
//
//  Description: Implements debounce filter on and off
//
//
//
//-----------------------------------------------------------------
module Debounce
#(parameter DEBOUNCE = 20'h30D3F)
(
  input       clk,        // System Clock
  input       reset,      // System Reset (Syncronous) 
  input       enable,     // Enable toggle
  input       signal_in,  // Signal to debounce
  output reg  signal_out  // Debounced Signal
);

  reg signal_in_Z1;
  reg signal_in_Z2;

  wire signal_logic1_strb;
  wire signal_logic0_strb;
  
  initial			
  begin
    signal_in_Z1 <= 1'b0;
    signal_in_Z2 <= 1'b0;
    signal_out 	 <= 1'b0;	
  end

  //Start strobe and enable semaphore
  always@(posedge clk)
  begin 
    if (reset) begin
        signal_in_Z1 <= 1'b0;
        signal_in_Z2 <= 1'b0;
    end else begin
        signal_in_Z1 <= signal_in;  
        signal_in_Z2 <= signal_in_Z1;  
    end
  end

  //Detect a rising or falling edge
  assign signal_change_strb = signal_in_Z1 ^ signal_in_Z2; 	

  //---------------------------------------------------------------
  //Sequence Counter to determine debounce logic high
  defparam Counter_Debounce1_i.dw = 20;
  defparam Counter_Debounce1_i.max = DEBOUNCE;
  //---------------------------------------------------------------
  Counter Counter_Debounce1_i 
  (
    .clk(clk),
    .reset(reset | signal_change_strb),
    .enable(signal_in_Z1),
    .cntr(),
    .strb(signal_logic1_strb)
  ); 
  
  //---------------------------------------------------------------
  //Sequence Counter to determine debounce logic low
  defparam Counter_Debounce0_i.dw = 20;
  defparam Counter_Debounce0_i.max = DEBOUNCE;
  //---------------------------------------------------------------
  Counter Counter_Debounce0_i 
  (
    .clk(clk),
    .reset(reset | signal_change_strb),
    .enable(~signal_in_Z1),
    .cntr(),
    .strb(signal_logic0_strb)
  );

  // Use strobes to set either logic 1 or 0
  always@(posedge clk)
  begin 
    if (reset)
      signal_out <= 1'b0;
    else if (signal_logic1_strb)
      signal_out <= 1'b1;  
    else if (signal_logic0_strb)
      signal_out <= 1'b0;  
  end
    
endmodule
