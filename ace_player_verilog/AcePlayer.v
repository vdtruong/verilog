// AcePlayer.v
///////////////////////////////////////////////////////////////////////////////
// Company: <Name>
//
// File: <Filename>
// File history:
//      A: 8/7/13: Initial
//      <Revision number>: <Date>: <Comments>
//      <Revision number>: <Date>: <Comments>
//
// Description: 
//
// This module will convert an ACE serial byte into the appropriate JTAG 
//	signals.
// Targeted device: <Family> <Die> <Package>
// Author: <Name>
//
///////////////////////////////////////////////////////////////////////////////

module AcePlayer 
(  
   input          clk,           // System Clock 
   input          rst,           // System Reset (Synchronous) 
   input          load,          // 
   input          tdo,  	       // 
   input    [7:0] data,  		     // Data received byte
   output   [7:0] prog_cntr,     // 
   output         tms,           // 
   output         tck,
   output         tdi,
   output         rdy,
   output         error,
   output         eof_done  
);			 
	// Declaring local parameters.
	// ace instructions
	localparam SHIFT_TMS 	  = 8'b0000_0010;	// Shift data to TMS pin
	localparam SHIFT_TDI 	  = 8'b0000_0011; 	// Shift data to TDI pin
	localparam SHIFT_CHECK  = 8'b0000_0100; 	// Shift data to TDI pin and
															// check TDO shifted in
	localparam RUNTEST 		  = 8'b0000_0101;	// RUNTEST – wait TCK cycles
															// w/o clocking TCK
	localparam EOF 			    = 8'b0000_0111;	// END

	// labels for micro-program - see spreadsheet table for description
	// important!  edit this table after adding / removing 
	//	any microprogram instructions
	localparam GET_INST 		   = 4'd8;
	localparam SHIFT_NXT_BYTE  = 7'd19;
	localparam RUNTEST_ENTRY 	 = 7'd21;
	localparam SHIFT_LOOP 		 = 7'd24;
	localparam END_TDO 			   = 7'd32;
	localparam TDO_CHECK 		   = 8'd34;
	localparam FILE_ERROR 		 = 8'd45;
	localparam TDO_CHK_ERROR	 = 8'd47;
	localparam INST_EOF 		   = 8'd49;
	localparam GET_BYTE 		   = 8'd55;
	localparam RESET_CHAIN 	   = 8'd60;

	// labels for controlling header reads 
   // toss 255 bytes of header to get to user-defined section
   // use 255 to toss rest (total 512) if not using header
   // or insert your code for what you use and change this
	// to toss remainder.  Also note, if you set to zero, 
	// you still need to include 2 null bytes at the beginning
	// of your file because the 2 tests are after 1st byte read
	localparam TOSS_HEADER1 = 8'd255; 
	// change this number to toss more out.
	// noticed the shift check commands do not work
	// for a couple of checks at the beginning of the file.
	// This is why we will toss out 106 more bytes to skip
	// these two check tests.
	// 255 + 255 + 106 + 2 = 618
	localparam TOSS_HEADER2 = 8'd255; 							  

	// labels for jtag output selector
	localparam SEL_RUNTEST  = 1'd0;
	localparam SEL_TMS 	   = 1'd1;
	localparam SEL_TDI 		= 2'd2;
	localparam SEL_TDO_CK 	= 4'd3;
	// End of local parameters.
	
	// Registers
   // program control
   reg [7:0] pc; 
   reg [7:0] branch_val; 
   reg [7:0] sub_return;
   // data registers
	reg [7:0]   reg1;
   reg [7:0]   reg2;
   reg [7:0]   data_in;
   reg [7:0]  	gp_count;

	reg [31:0]  num_bits; 

	reg 	      count_en;
   reg         count_once;
   reg         count_strobe; 
   reg         shift_en;
   reg         shift_strobe; 
   reg         shift_once;
   reg         shift_done; 
   reg         mask_tdo;
   reg         shift_count_en;
   reg         shift_count_strobe;
   reg         shift_count_once; 
   reg         tdo_compare;
   reg         more_bytes;
   reg         count_zero;
   reg         dec_bits; 
   reg         dec_bits_strobe; 
   reg         dec_bits_once;
   reg         tdo_shift_en;
   reg         tdo_shift_once;
   reg         tdo_shift_strobe;
	reg         load_once;
   reg         load_en;
   reg         exit_shift;
   reg         meta1_ff; 
   reg         meta2_ff;
   reg         tms_reg; 
   reg         tck_reg;
   reg         tdi_reg;
   reg         error_reg;
   reg         eof_done_reg;		  	

   // controls jtag outputs
	reg [3:0]   output_sel;  
   // jtag shift registers
	reg [7:0]   tdo_val;
   reg [7:0]   shift_in;

	reg [2:0]   shift_count;
   reg [2:0]   pad_shift;

	reg         tck_s;
   reg         tms_s; 			
	reg			rdy_reg;	 
	
	// sensitivity list for pc state machine outputs
	reg [3:0]	output_sel_sl;	
	reg			rdy_reg_sl;	 
	reg			tck_s_sl;   
	reg			error_reg_sl; 
	reg			eof_done_reg_sl; 
	reg			count_en_sl; 
   reg [7:0]   sub_return_sl;
   reg [7:0]   data_in_sl;
   reg         dec_bits_sl; 
   reg         shift_en_sl; 		  
	reg         shift_count_en_sl;
   reg [2:0]   pad_shift_sl;
   reg         tms_s_sl;		
   reg         tdo_shift_en_sl;	
   reg         mask_tdo_sl;  

   // Initialize registers
   initial 
   begin
  		pc                   <= {8{1'b0}};
      branch_val           <= {8{1'b0}}; 
      sub_return           <= {8{1'b0}}; 
      sub_return_sl        <= {8{1'b0}};
	   reg1                 <= {8{1'b0}};
      reg2                 <= {8{1'b0}};
      data_in              <= {8{1'b0}};
      data_in_sl           <= {8{1'b0}};
      gp_count             <= {8{1'b0}};
	   num_bits             <= {32{1'b0}};
	   count_en             <= 1'b0;		  
	   count_en_sl          <= 1'b0;
      count_once           <= 1'b0;
      count_strobe         <= 1'b0; 
      shift_en             <= 1'b0;	
      shift_en_sl          <= 1'b0;
      shift_strobe         <= 1'b0; 
      shift_once           <= 1'b0;
      shift_done           <= 1'b0; 
      mask_tdo             <= 1'b0; 
      mask_tdo_sl          <= 1'b0;
      shift_count_en       <= 1'b0;
      shift_count_en_sl    <= 1'b0;
      shift_count_strobe   <= 1'b0;
      shift_count_once     <= 1'b0; 
      tdo_compare          <= 1'b0;
      more_bytes           <= 1'b0;
      count_zero           <= 1'b0;
      dec_bits             <= 1'b0; 	 
      dec_bits_sl          <= 1'b0; 
      dec_bits_strobe      <= 1'b0; 
      dec_bits_once        <= 1'b0;
      tdo_shift_en         <= 1'b0;	 
      tdo_shift_en_sl      <= 1'b0;
      tdo_shift_once       <= 1'b0;
      tdo_shift_strobe     <= 1'b0;
	   load_once            <= 1'b0;
      load_en              <= 1'b0;
      exit_shift           <= 1'b0;
      meta1_ff             <= 1'b0; 
      meta2_ff             <= 1'b0;
	   output_sel           <= {4{1'b0}};		  
	   output_sel_sl        <= {4{1'b0}};
	   tdo_val              <= {8{1'b0}};
      shift_in             <= {8{1'b0}};
	   shift_count          <= {3{1'b0}}; 
      pad_shift            <= {3{1'b0}};
      pad_shift_sl         <= {3{1'b0}};
	   tck_s                <= 1'b0;					  
	   tck_s_sl             <= 1'b0;
      tms_s                <= 1'b0;
      tms_s_sl             <= 1'b0;
      tms_reg              <= 1'b0;
      tck_reg              <= 1'b0;
      tdi_reg              <= 1'b0;	 
      rdy_reg              <= 1'b0;	 
      rdy_reg_sl           <= 1'b0;		 
      error_reg	         <= 1'b0; 
      error_reg_sl         <= 1'b0;  
      eof_done_reg	      <= 1'b0;
      eof_done_reg_sl      <= 1'b0;
   end   									  
   
   /// Assigning the outputs /////   	
	assign prog_cntr 	= pc;  
	assign rdy 			= rdy_reg;  
	assign error 		= error_reg;
	assign eof_done	= eof_done_reg;
	assign tms			= tms_reg; 		
	assign tdi			= tdi_reg; 		
	assign tck			= tck_reg;
   ////// End of assigning outputs /////										
   																 											   
   // create delays      
   always @(posedge clk)
   begin
      if (rst) begin
         meta1_ff          <= 1'b0;
			meta2_ff          <= 1'b0;
			load_once         <= 1'b0;
         shift_once        <= 1'b0;
         shift_count_once  <= 1'b0;
         tdo_shift_once    <= 1'b0;
         dec_bits_once     <= 1'b0;
         count_once        <= 1'b0;
      end
      else begin 
		   meta1_ff 			<= load;
			meta2_ff 			<= meta1_ff;
			load_once 			<= meta2_ff;
         shift_once        <= shift_en;
         shift_count_once  <= shift_count_en;
         tdo_shift_once    <= tdo_shift_en;
         dec_bits_once     <= dec_bits;
         count_once        <= count_en;
      end
   end
   ////// done with delays //////////			
	
   // create strobes from rising edges.
   always @(posedge clk)
   begin
      if (rst) 
         shift_strobe <= 1'b0; 
	   else if (shift_en && !shift_once)
         shift_strobe <= 1'b1;
      else 
         shift_strobe <= 1'b0;
   end
      
   always @(posedge clk)
   begin
      if (rst) 
         tdo_shift_strobe <= 1'b0; 
	   else if (tdo_shift_en && !tdo_shift_once)
         tdo_shift_strobe <= 1'b1;
      else 
         tdo_shift_strobe <= 1'b0;
   end
      
   always @(posedge clk)
   begin
      if (rst) 
         count_strobe <= 1'b0; 
	   else if (count_en && !count_once)
         count_strobe <= 1'b1;
      else 
         count_strobe <= 1'b0;
   end
      
   always @(posedge clk)
   begin
      if (rst) 
         shift_count_strobe <= 1'b0; 
	   else if (shift_count_en && !shift_count_once)
         shift_count_strobe <= 1'b1;
      else 
         shift_count_strobe <= 1'b0;
   end
      
   always @(posedge clk)
   begin
      if (rst) 
         dec_bits_strobe <= 1'b0; 
	   else if (dec_bits && !dec_bits_once)
         dec_bits_strobe <= 1'b1;
      else 
         dec_bits_strobe <= 1'b0;
   end
      
   always @(posedge clk)
   begin
      if (rst) 
         load_en <= 1'b0; 
	   else if (meta2_ff && !load_once)
         load_en <= 1'b1;
      else 
         load_en <= 1'b0;
   end
   /// end of creating strobes //////
   
   /// Gate the sensitivity list /////	
   always @(posedge clk)
   begin
      if (rst) 		  				  
	   	output_sel_sl  <= {4{1'b0}};
      else 										 						 		  
	   	output_sel_sl	<= output_sel;
   end											   	 
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   
      	sub_return_sl  <= {8{1'b0}};
      else 										 
      	sub_return_sl	<= sub_return;
   end			 
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	  	 
      	data_in_sl           <= {8{1'b0}};
      else 										
      	data_in_sl           <= data_in;
   end												
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	  	 			  
	   	count_en_sl          <= 1'b0;
      else 										  			  
	   	count_en_sl          <= count_en; 
   end												
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   		
      	shift_en_sl          <= 1'b0;
      else 										  		
      	shift_en_sl          <= shift_en; 
   end												
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	
      	mask_tdo_sl          <= 1'b0;
      else 										  	
      	mask_tdo_sl          <= mask_tdo; 
   end												
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	
      	shift_count_en_sl    <= 1'b0;
      else 										  	
      	shift_count_en_sl    <= shift_count_en; 
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	 	 
      	dec_bits_sl          <= 1'b0;
      else 										  		 	 
      	dec_bits_sl          <= dec_bits;
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   		 
      	tdo_shift_en_sl      <= 1'b0;
      else 										  		 
      	tdo_shift_en_sl      <= tdo_shift_en;
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   		 
      	pad_shift_sl         <= {3{1'b0}};
      else 										  	 	 
      	pad_shift_sl         <= pad_shift;
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   		 					  
	   	tck_s_sl             <= 1'b0;
      else 										  	 					  
	   	tck_s_sl             <= tck_s;
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	
      	tms_s_sl             <= 1'b0;
      else 										
      	tms_s_sl             <= tms_s;
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	
      	rdy_reg_sl           <= 1'b0;		
      else 										
      	rdy_reg_sl           <= rdy_reg;		
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	
      	error_reg_sl         <= 1'b0;  		
      else 										  
      	error_reg_sl         <= error_reg;  		
   end														
																	 
   always @(posedge clk)
   begin
      if (rst) 		  				   	
      	eof_done_reg_sl      <= 1'b0; 		
      else 										  	 
      	eof_done_reg_sl      <= eof_done_reg;  		
   end													
	// Done with sensitivity list gating ///										 

   always @(posedge clk)
   begin
      if (rst) 
         gp_count <= {8{1'b0}}; 
	   else if (count_strobe)
	      gp_count <= gp_count - 1'b1;
	   else if (pc == 2)
	      gp_count <= TOSS_HEADER1;
	   else if (pc == 5)
	      gp_count <= TOSS_HEADER2;
      else 
         gp_count <= gp_count;
   end
				  
      
   always @(posedge clk)
   begin
      if (rst) 
         count_zero 	<= 1'b0;
	   else if (gp_count == 8'b0000_0000) 
		   count_zero  <= 1'b1;
      else 
         count_zero 	<= 1'b0;
   end
      
   always @(posedge clk)
   begin
      if (rst) begin 
         reg2        <= {8{1'b0}};
	      tdo_val     <= {8{1'b0}};
      end
	   else if (tdo_shift_strobe) begin
         // left shift
         reg2[7] 	   <= reg2[6];
         reg2[6] 	   <= reg2[5];
         reg2[5] 	   <= reg2[4];
         reg2[4] 	   <= reg2[3];
         reg2[3] 	   <= reg2[2];
         reg2[2] 	   <= reg2[1];
         reg2[1] 	   <= reg2[0];
			reg2[0] 		<= tdo_val[0];
         // right shift
		   tdo_val[0]  <= tdo_val[1];
		   tdo_val[1]  <= tdo_val[2];
		   tdo_val[2]	<= tdo_val[3];
		   tdo_val[3]	<= tdo_val[4];
		   tdo_val[4]	<= tdo_val[5];
		   tdo_val[5]	<= tdo_val[6];
		   tdo_val[6]	<= tdo_val[7]; // where does tdo_val[7] get its data? 
      end
	   else if (shift_strobe) begin
         // left shift
         tdo_val[7] 	<= tdo_val[6];
         tdo_val[6] 	<= tdo_val[5];
         tdo_val[5] 	<= tdo_val[4];
         tdo_val[4] 	<= tdo_val[3];
         tdo_val[3] 	<= tdo_val[2];
         tdo_val[2] 	<= tdo_val[1];
         tdo_val[1] 	<= tdo_val[0];
			tdo_val[0] 	<= tdo; 
      end
	   else if (mask_tdo) begin
		   reg2        <= data_in & reg2; 
      end
      else begin
         reg2        <= reg2;
		   tdo_val     <= tdo_val;
      end
   end
      
   always @(posedge clk)
   begin
      if (rst) begin 
         shift_in    <= {8{1'b0}};
      end
	   else if (shift_strobe) begin
         // right shift
		   shift_in[0] <= shift_in[1];
		   shift_in[1] <= shift_in[2];
		   shift_in[2]	<= shift_in[3];
		   shift_in[3]	<= shift_in[4];
		   shift_in[4]	<= shift_in[5];
		   shift_in[5]	<= shift_in[6];
		   shift_in[6]	<= shift_in[7]; 
		   shift_in[7]	<= 1'b0; 
      end
	   else if (pc == 60) begin
		   shift_in 	<= 8'b1111_1111; 
      end
	   else if (pc == 20) begin
		   shift_in 	<= data_in; 
      end
      else begin
		   shift_in    <= shift_in;
      end
   end

   always @(posedge clk)
   begin
      if (rst) 
	      shift_count <= {3{1'b0}};
	   else if (shift_count_strobe) 
		   shift_count <= shift_count -1;
	   else if (pc == 22) 
		   shift_count <= 3'h7;
	   else if (pc == 23) 
		   shift_count <= num_bits[2:0];
	   else if (pc == 60) 
		   shift_count <= 3'b100;
      else 
		   shift_count <= shift_count;
   end

   always @(posedge clk)
   begin
      if (rst)
	      num_bits          <= {32{1'b0}};
	   else if (dec_bits_strobe) 
		   num_bits          <= num_bits - 8;
	   else if (pc == 17) 
			num_bits[31:24]   <= data_in;
	   else if (pc == 15) 
			num_bits[23:16]   <= data_in;
	   else if (pc == 13) 
			num_bits[15:8]    <= data_in;
	   else if (pc == 11) 
			num_bits[7:0]     <= data_in;
      else 
		   num_bits          <= num_bits;
   end

   always @(posedge clk)
   begin
      if (rst) 
	      reg1 <= {8{1'b0}};
	   else if (mask_tdo)  
		   reg1 <= data_in & reg1;
	   else if ((pc == 9) || (pc == 38))   
		   reg1 <= data_in;
      else
			reg1 <= reg1;
   end
      
   always @(posedge clk)
   begin
      if (rst) 
         more_bytes <= 1'b0; 
	   else if (num_bits > 32'h0000_0007)
	      more_bytes <= 1'b1;
      else 
         more_bytes <= 1'b0;
   end
   /// Done with responses gating. /////////
      
   // combinational
   always @(output_sel, shift_in[0], tck_s, tms_s)
   begin
      case (output_sel)
      	SEL_TMS :
         	begin
   				tdi_reg = 1'b0; 
   			   tms_reg = shift_in[0]; 
   				tck_reg = tck_s;
         	end
      	SEL_TDI :
         	begin
   			   tdi_reg = shift_in[0]; 
   				tms_reg = tms_s; 
   				tck_reg = tck_s;
         	end
      	SEL_TDO_CK :
         	begin
   			   tdi_reg = shift_in[0]; 
   				tms_reg = tms_s; 
   				tck_reg = tck_s;
         	end
      	SEL_RUNTEST :
         	begin
   			   tdi_reg = 1'b0; 
   				tms_reg = 1'b0; 
   				tck_reg = 1'b0;
         	end
      	default :
         	begin
   			   tdi_reg = 1'b0; 
   				tms_reg = 1'b0; 
   				tck_reg = 1'b0;
         	end
      endcase
   end
      
   always @(rst, shift_count)
   begin
      if (rst) 
         shift_done = 0;
		else if (shift_count == 3'b000)  
			shift_done = 1'b1; 
	   else 
         shift_done = 1'b0;
   end
	
   always @(rst, more_bytes, shift_done)
   begin
      if (rst) 
         exit_shift = 0;
		else if (!more_bytes && shift_done)  
			exit_shift = 1'b1; 
	   else 
         exit_shift = 1'b0;
   end
	
	always @(rst, reg2, reg1)
   begin
      if (rst) 
         tdo_compare = 1'b0;
		else if (reg2 == reg1)  
			tdo_compare = 1'b1; 
	   else 
         tdo_compare = 1'b0;
   end
	///  End of combinational /////
	
	// The following three always block are for the
	// pc state machine.
	
   // Sequential for next state.
   always @(posedge clk)
   begin
      if (rst) 
         pc <= 1'b0;   		// present state
      else 
         pc <= branch_val; // present state = next state
   end

   // State machine: next state.
   always @(pc, count_zero, reg1, more_bytes, shift_done, output_sel,
            tdo_compare, load_en, sub_return)
   begin
		// consult the spreadsheet included in your download for 
		// description of this case stmt
      case (pc)
      	0 :   // idle
            begin								// present state = next state 
					branch_val 	= pc + 1;	// pc = branch_val 	= pc + 1 
         	end
      	1 :   // reset JTAG Bus to Test Logic Reset
            begin
					branch_val 	= RESET_CHAIN; // 8'd60
         	end
      	2 :   // start ACE File
				   // toss 1st 256 bytes which takes you the user-defined area  
					// of the header
            begin
					branch_val 	= pc + 1;
         	end
      	3 :   // for simulation, remember that you can adjust toss header
				   // constant to small number
            begin
					branch_val 	= GET_BYTE; // 8'd55
         	end
      	4 :   
            begin  
					if (count_zero)
					   branch_val  = pc + 1; 
					else 
						branch_val 	= pc - 1 ; 
         	end
      	5 :   
            begin
					branch_val 	= pc + 1;
         	end
      	6 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	7 :   
            begin  
					if (count_zero)
					   branch_val  = pc + 1; 
					else 
						branch_val 	= pc - 1 ; 
         	end
			// GET_INST, this may not be the correct comment.
      	8 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	9 :   
            begin
					branch_val 	= pc + 1;
         	end
      	10 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	11 :   
            begin
					branch_val 	= pc + 1;
         	end
      	12 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	13 :   
            begin
					branch_val 	= pc + 1;
         	end
      	14 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	15 :   
            begin
					branch_val 	= pc + 1;
         	end
      	16 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	17 :   
            begin
					branch_val 	= pc + 1;
         	end
      	18 :  // -- evaluate instruction
            begin
				   case (reg1)  
					   EOF: 
						   branch_val = INST_EOF; 			// 8'd49
						SHIFT_TMS:
						   branch_val = SHIFT_NXT_BYTE;	// 7'd19
						SHIFT_TDI: 
							branch_val = SHIFT_NXT_BYTE; 	// 7'd19
						SHIFT_CHECK: 
							branch_val = SHIFT_NXT_BYTE; 	// 7'd19
						RUNTEST: 
							branch_val = RUNTEST_ENTRY; 	// 7'd21	
						default:
							branch_val = FILE_ERROR;		// 7'd45
					endcase
         	end
			// SHIFT_NXT_BYTE
      	19 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	20 :   
            begin
					branch_val 	= pc + 1;
         	end
         // RUNTEST_ENTRY
      	21 : 
            begin  
					if (more_bytes)
					   branch_val  = pc + 1; 
					else 
						branch_val 	= pc + 2 ; 
         	end
      	22 :   
            begin
					branch_val 	= pc + 2;
         	end
      	23 :   
            begin
					branch_val 	= pc + 1;
         	end
      	24 :   
            begin
					branch_val 	= pc + 1;
         	end
      	25 :   
            begin
					branch_val 	= pc + 1;
         	end
      	26 :  // extra TCK - clk divide
            begin
					branch_val 	= pc + 1;
         	end
      	27 :   
            begin
					branch_val 	= pc + 1;
         	end
      	28 :   
            begin
					branch_val 	= pc + 1;
         	end
      	29 :   
            begin
					branch_val 	= pc + 1;
         	end
      	30 : 
            begin  
					if (shift_done)
					   branch_val  = pc + 1; 
					else 
						branch_val 	= pc - 6 ; 
         	end
      	31 : 
            begin  
					if (output_sel == SEL_TDO_CK)	// 4'd3
					   branch_val  = TDO_CHECK; 	// 8'd34 
					else 
						branch_val 	= pc + 1 ; 
         	end
      	32 : 
            begin  
					if (more_bytes)
					   branch_val  = pc + 1;  
					else 
						branch_val 	= GET_INST; // 4d'8 
         	end
      	33 : 
            begin  
					if (output_sel == SEL_RUNTEST)
					   branch_val  = RUNTEST_ENTRY;  // 7'd21
					else 
						branch_val 	= SHIFT_NXT_BYTE; // 7'd19 
         	end				 
			// TDO_CHECK
      	34 :   
            begin
					branch_val 	= pc + 1;
         	end
      	35 :   
            begin
					branch_val 	= pc + 1;
         	end
      	36 : 
            begin  
					if (shift_done)
					   branch_val  = pc + 1; 
					else 
						branch_val 	= pc - 1; 
         	end
      	37 :  
            begin
					branch_val 	= GET_BYTE;
         	end
      	38 :  // --tdo expected
            begin
					branch_val 	= pc + 1;
         	end
      	39 :   
            begin
					branch_val 	= GET_BYTE;
         	end
      	40 :  // --mask reg2 with data_in
            begin
					branch_val 	= pc + 1;
         	end
      	41 :  // -- wait for compare circuit to settle
            begin
					branch_val 	= pc + 1;
         	end
      	42 : 
            begin  
					if (tdo_compare)
					   branch_val  = END_TDO;        // 7'd32 
					else 
						branch_val 	= TDO_CHK_ERROR;  // 8'd47 
         	end
      	45 :  // FILE_ERROR_REG 
            begin
					branch_val 	= RESET_CHAIN; // 8'd60
         	end
      	47 :  // TDO_CHECK error_reg
            begin
					branch_val 	= RESET_CHAIN; // 8'd60
         	end
      	49 :  
            begin
					branch_val 	= RESET_CHAIN; // 8'd60
         	end
      	55 :  
            begin
					branch_val 	= pc + 1;
         	end
      	56 : 
            begin  
					if (load_en)
					   branch_val  = pc + 1;         
					else // wait here, could be wrong
						branch_val 	= pc;    
         	end
      	57 :  // get data in
            begin
					branch_val 	= sub_return;
         	end
      	60 :  
            begin
					branch_val 	= pc + 1;
         	end
      	61 :   
            begin
					branch_val 	= pc + 1;
         	end
      	62 :   
            begin
					branch_val 	= pc + 1;
         	end
      	63 : 
            begin  
					if (shift_done)
					   branch_val  = sub_return; 
					else 
						branch_val 	= pc - 2; 
         	end
         default:
            begin
               branch_val = 0;
            end
      endcase
   end
   
   // State machine: outputs.
   always @(pc, output_sel_sl, rdy_reg_sl, tck_s_sl, error_reg_sl, 
            eof_done_reg_sl, count_en_sl, sub_return_sl,  
            reg1, dec_bits_sl, shift_en_sl, num_bits, more_bytes, 
            shift_count_en_sl, pad_shift_sl, exit_shift, data,
				tms_s_sl, tdo_shift_en_sl, mask_tdo_sl, data_in_sl)
   begin
		// consult the spreadsheet included in your download for 
		// description of this case stmt
      case (pc)
      	0 :   // idle
            begin
				   output_sel 	      = SEL_RUNTEST;	// 1'd0 
					rdy_reg 			   = 1'b0;  
					tck_s 		      = 1'b0;
					error_reg 		   = 1'b0; 
					eof_done_reg 	   = 1'b0; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
			      shift_count_en    = shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
      	1 :   // reset JTAG Bus to Test Logic Reset
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;	// 2
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
      	2 :   // start ACE File
				   // toss 1st 256 bytes which takes you to the user-defined area  
					// of the header
         	begin
				   output_sel        = SEL_RUNTEST;   // 1'd0
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
      	3 :   // for simulation, remember that you can adjust toss header
				   // constant to small number
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;	// 4
				   count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
      	4 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 	      	= tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = 1'b1;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
			// insert code here if you want to evaluate user-defined header 
			// information.  
			// then set TOSS_HEADER2 to remainder you want to toss.  
			// Otherwise toss next 256 bytes
      	5 :   
         	begin
				   output_sel 	      = SEL_RUNTEST;	// 1'd0
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
 					count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
			// for simulation, remember that you can adjust toss header 
			// constant to small number
      	6 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;	// 7
				   count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
      	7 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = 1'b1;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end
      	8 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	9 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en          = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	10 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	11 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = 1'b0;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	12 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	13 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	14 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl; 
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	15 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
					count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	16 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	17 :   
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= 1'b0;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	18 :   
         	begin
				   case (reg1)  
					   SHIFT_TMS   :
							output_sel  = SEL_TMS;	 	// 1'd1
						SHIFT_TDI   :
							output_sel  = SEL_TDI;		// 2'd2
						SHIFT_CHECK :
							output_sel  = SEL_TDO_CK;	// 4'd3
						RUNTEST     :
						   output_sel  = SEL_RUNTEST;	// 1'd0	
						default     :
						   output_sel  = SEL_RUNTEST;	// 1'd0
					endcase 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	19 :  // SHIFT_NXT_BYTE  
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = 1'b0;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl; 
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	20 :    
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	21 :  // RUNTEST_ENTRY    
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = 1'b0;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	22 :  
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl; 
					pad_shift 	      = 3'h7;	  
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
            end
      	23 :  
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl; 
					pad_shift 	      = num_bits[2:0];
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
				end
      	24 :  
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = 1'b0;	// wait for exit_shift
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
				end
      	25 :  
         	begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;	
					pad_shift 	      = pad_shift_sl;  
					if (exit_shift) 
						tms_s 			= 1'b1; 
					else 
						tms_s 			= 1'b0;				
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
				end									 
      	26 :   
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = 1'b1;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end											
      	27 :   
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = 1'b1;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= 1'b1;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end											
      	28 :   											  
				// fyi - an easy way to divide jtag clock further is to add 
				// extra '1' and '0' states here
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = 1'b0;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= 1'b0;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= 1'b0;				
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end											
      	29 :   										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = 1'b0;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= 1'b0;
               shift_count_en    = shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= 1'b0;	// extra TCK clk div
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	30 :   										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= 1'b1;    
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	31 :   										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits          = dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	32 :   										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;	
					if (more_bytes) begin 
						dec_bits 		= 1'b1; 
					end  
					else begin																		
						dec_bits       = dec_bits_sl;
					end
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;			
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	33 :   										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= 1'b0;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	34 : 	// TDO_CHECK  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= 1'b0;			
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	35 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= 1'b0;    
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= 1'b1;			
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	36 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= 1'b1;     
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= 1'b0;			
					mask_tdo 			= mask_tdo_sl;		
					data_in 				= data_in_sl;
         	end																			  
      	37 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	38 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;		
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	39 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	40 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= 1'b1;			
					data_in 				= data_in_sl;
         	end																			  
      	41 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= 1'b0;			
					data_in 				= data_in_sl;
         	end																			  
      	42 : 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;
         	end																			  
      	45 :	// FILE_ERROR_REG 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl; 
					sub_return 	      = pc + 1;	// reset JTAG Bus
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;			 
				end																			  
      	46 :	 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = 1'b1; 
					eof_done_reg 	   = 1'b1;	// stop here
					sub_return 	      = sub_return_sl;	
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;			 
				end																			  
      	47 :	// TDO_CHECK error_reg	 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = pc + 1;	// reset JTAG Bus
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;			 
				end																			  
      	48 :		 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = 1'b1; 
					eof_done_reg 	   = 1'b0;	// stop here	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;			 
				end																			  
      	49 :	// EOF		 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl; 
					eof_done_reg 	   = eof_done_reg_sl;		
					sub_return 	      = pc + 1;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;			 
				end																			  
      	50 :			 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = 1'b0;	 
					eof_done_reg 	   = 1'b1;	// stop here	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;			 
				end																			  
      	55 :	// get byte			 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = 1'b1;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = 1'b0;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;		
					data_in 				= data_in_sl;		 
				end																			  
      	56 :				 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;	
					data_in 				= data_in_sl;					 
				end																			  
      	57 :				 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = 1'b0;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;
					data_in 				= data;			 
				end																			  
      	60 :	// Reset JTAG chain				 	  										
            begin
				   output_sel 	      = SEL_TMS; // 1'd1
					rdy_reg 			   = 1'b0;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;	
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;		  
					shift_count_en 	= shift_count_en_sl;
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;
					data_in 				= data_in_sl;			 
				end																			  
      	61 :				 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = 1'b1;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= 1'b1;
					shift_count_en 	= 1'b0;     
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;
					data_in 				= data_in_sl;			 
				end																			  
      	62 :				 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = 1'b0;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= 1'b0;
					shift_count_en 	= shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;
					data_in 				= data_in_sl;			 
				end					 						  
      	63 :				 	  										
            begin
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= 1'b1;    
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;
					data_in 				= data_in_sl;			 
				end
      	default :
         	begin																	  
				   output_sel 	      = output_sel_sl; 
					rdy_reg 			   = rdy_reg_sl;  
					tck_s 		      = tck_s_sl;
					error_reg 		   = error_reg_sl;	 
					eof_done_reg 	   = eof_done_reg_sl;	
					sub_return 	      = sub_return_sl;
				   count_en 	      = count_en_sl;
					dec_bits 			= dec_bits_sl;
					shift_en 			= shift_en_sl;
					shift_count_en 	= shift_count_en_sl; 
					pad_shift 	      = pad_shift_sl;
					tms_s					= tms_s_sl;		
					tdo_shift_en 		= tdo_shift_en_sl;
					mask_tdo 			= mask_tdo_sl;
					data_in 				= data_in_sl;	
         	end
      endcase
   end 					  			
	// End of pc state machine. 

endmodule