//-----------------------------------------------------------------
//  Module:     CommModeRouteThru
//  Project:    generic atomic modules
//  Version:    0.01-1
//
//  Description: Implements a route through switch for coms
//  Switch is either bus1 to bus2 or bus 1 to bus 3
//
//
//-----------------------------------------------------------------
module CommModeRouteThru
(
  input       clk,      // System Clock
  input       reset,    // System Reset (Syncronous) 
  input       sw_mode,  // Flag to indicate switch 1<->2 to 1<->3;
  input       bus1_rx,  // 
  output  reg bus1_tx,  // 
  input       bus2_rx,  // 
  output  reg bus2_tx,  // 
  input       bus3_rx,  // 
  output  reg bus3_tx   // 
);

  wire bus1_tx_wire;
  wire bus2_tx_wire;
  wire bus3_tx_wire;

	initial			
	begin
		bus1_tx <= 1'b1;
    bus2_tx <= 1'b1;
    bus3_tx <= 1'b1;
	end

  assign bus2_tx_wire = (sw_mode) ? 1'b1 : bus1_rx;
  
  always@(posedge clk)
  begin
    if (reset)
      bus2_tx <= 1'b1;
    else      
      bus2_tx <= bus2_tx_wire;
  end 
       
  assign bus3_tx_wire = (sw_mode) ? bus1_rx : 1'b1;
  
  always@(posedge clk)
  begin
    if (reset)
      bus3_tx <= 1'b1;
    else      
      bus3_tx <= bus3_tx_wire;
  end  

  assign bus1_tx_wire = (sw_mode) ? bus3_rx : bus2_rx;
  
  always@(posedge clk)
  begin
    if (reset)
      bus1_tx <= 1'b1;
    else      
      bus1_tx <= bus1_tx_wire;
  end
  
              
endmodule
