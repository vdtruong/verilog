//-----------------------------------------------------------------
//  Module:     FallingEdgeStrobe
//  Project:    generic atomic modules
//  Version:    0.01-1
//
//  Description: Implements a JK FF with enable
//
//
//
//-----------------------------------------------------------------
module FallingEdgeStrobe
(
  input       clk,        // System Clock
  input       reset,      // System Reset (Syncronous) 
  input       enable,     // Enable toggle
  input       signal,     // Signal to detect edge rising edge
  output      edge_strb   // edge strobe
);

  reg signal_active;
  reg signal_activeZ1;
  
	initial			
	begin
    signal_active   <= 1'b0;
    signal_activeZ1 <= 1'b0;
	end

  //Start strobe and enable semaphore
  always@(posedge clk)
  begin 
    if (reset)
        signal_active <= 1'b0;
    else
        signal_active <= signal;  
  end
  
  always@(posedge clk)
  begin 
    if (reset)
        signal_activeZ1 <= 1'b0;
    else
        signal_activeZ1 <= signal_active;  
  end

  assign edge_strb = ~signal_active & signal_activeZ1 & enable;	
    
endmodule
