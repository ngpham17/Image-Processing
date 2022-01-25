/*
	Image Processing
	Author: Nguyen Pham
*/
module vga(
	input wire reset,
	input wire [15:0]	switches,	//active high test mode enable
	input wire			vga_clk,	// 31.5Mhz clock
	
	//wishbone
	input wire 		clk,			// regular 100Mhz clock
	input wire 		wb_rst,
	input wire 		wb_m2s_vga_we,
	input wire 		wb_m2s_vga_stb,
	input wire 		wb_m2s_vga_cyc,
	input wire [31:0] 	wb_m2s_vga_dat,
	output wire[31:0] 	wb_s2m_vga_dat,
	output wire 		wb_s2m_vga_ack,
	
	output wire 		vga_vs,		//vga high sync
	output wire			vga_hs,		// vga low sync
	output logic [3:0]	vga_r,	//output color
	output logic [3:0] 	vga_b,	//output color
	output logic [3:0]	vga_g	//output color
);

	wire [31:0] pix_num;		// the number of pixels
	wire [11:0] pixel_row;		// the number of pixel on a row
	wire [11:0] pixel_column;	// the number of pixel on a column
	wire video_on;				// video signal to make an image on or off
	wire [3:0] doutb;			// data out from block memory generator which is created in IP catalog
	
	// 2 sensitive registers
	reg wb_vga_ack_ff;		// flipflop output
							//acknowledge to send back to wb, 
							// data is ready but we want to wait 
							// one more cycle for more thing propagate
							// -> wait a cycle before we send data out
							
	reg [31:0] wb_vga_reg;	// hold 16 bits of col and 16 bits of row
	
// Instantiate Display Timing Generator
	dtg vga_dtg(
		.clock(vga_clk),
		.rst(reset),
		.video_on(video_on),
		.horiz_sync(vga_hs),
		.vert_sync(vga_vs),
		.pixel_row(pixel_row), 
		.pixel_column (pixel_column),
		.pix_num(pix_num)		// read address
	);	
	
	// memory hold the background image
	blk_mem_gen_0 vga_memory(
		.clka	(vga_clk),
		.addra  (19'b0),
		.dina   (4'b0),
		.wea    (1'b0),
		.addrb	(pix_num),
		.clkb	(vga_clk),
		.doutb	(doutb)
		);
	
	logic [3:0] pix_row_save[640:0] ;		//memory store all pixels on each row when the vga scan row by row
	
	logic [3:0] pix_val;	// the pixel value at the current position
	logic [4:0] Gx;			// Robert cross Gx
	logic [4:0] Gy;			// Robert cross Gy
	logic [4:0] G;			// Robert cross G
	integer i;				// the interger i
	
	assign pix_val =  doutb;
	
	// Check Switches
	always_comb begin
	   if(video_on) begin	// if video_on is high/1
	       //Robert Cross
			if (switches[2] || switches[3]) begin
				// 2x2 matrix of pixel variables to do math on
				// It should be 	pix_row_save[640 | pix_row_save[639]
				// 					pix_row_save[0]  | pix_val
				for (i = 640; i > 0; i = i - 1) begin
					pix_row_save[i] = pix_row_save[i-1];
				end	//loop
				pix_row_save[0] = pix_val;
				
				// do Robert cross algorithm
				//Gx
				if (pix_row_save[640] >= pix_val)
				    Gx = pix_row_save[640] - pix_val;
				else
				    Gx = pix_val - pix_row_save[640];
				 
				// Gy
				if(pix_row_save[639] >= pix_row_save[0])
				    Gy = pix_row_save[639] - pix_row_save[0];
				else
				     Gy = pix_row_save[0] - pix_row_save[639];
				
				//G
				G = Gx + Gy;  
	       end // if
	       
           //Switches
           case (switches[3:0])
				// sw0
               4'b0001: begin
                    if (pix_num[3] ==1) begin
                        vga_r = {4{~pix_num[3]}};	// assign bit 4 of pix_num to the output
                        vga_g = {4{~pix_num[3]}};	// assign bit 4 of pix_num to the output
                        vga_b = {4{~pix_num[3]}};	// assign bit 4 of pix_num to the output
                   end				
                   else begin
                        vga_r = doutb;			// display the background image
                        vga_b = doutb;			// display the background image
                        vga_g = doutb;			// display the background image
                   end
			   end   //4'b0001
			   
               //sw1
               4'b0010: begin
                  if (doutb > {switches[6:4], 1'b0}) begin	// threshold is {switches[6:4], 1'b0}
                       // output is WHITE
                       vga_r = 4'hf;	 
                       vga_g = 4'hf;
                       vga_b = 4'hf;
                  end // if
                  
                  else begin
                       // output is BLACK
                       vga_r = 4'h0;
                       vga_g = 4'h0;
                       vga_b = 4'h0;
                  end // else
               end	//	4'b0010
			   
                //sw2
              	4'b0100: begin
					vga_r = G[4:1];		// get 4 bit of G from bit 1 to 4
					vga_b = G[4:1];		// get 4 bit of G from bit 1 to 4
					vga_g = G[4:1];		// get 4 bit of G from bit 1 to 4
				end	//	4'b0100
						
               //sw3
               	4'b1000:
					if( G > {1'b0,switches[6:4],1'b0}) begin	// threshold {1'b0,switches[6:4],1'b0}
					   // output is WHITE
						vga_r =	4'hf; 		
						vga_b = 4'hf;
						vga_g = 4'hf;
					end	// if
					
					else begin
					   // output is BLACK
						vga_r =	4'h0; 
						vga_b = 4'h0;
						vga_g = 4'h0;
					end	//	else
				
               // default is the background image
               default: {vga_r, vga_g, vga_b} = {3{doutb}};
            endcase   //case
       end //if
	   
       else begin		// video_on is low/0
			vga_r = 4'h0;
			vga_b = 4'h0;
			vga_g = 4'h0;
		end	// else
    end // comb 
	
//	always @(posedge clk, posedge wb_rst) begin
    always_comb begin
		if (wb_rst) begin
			wb_vga_reg = 32'h0040_0040 ;	// default position of the sprite on the screen
			wb_vga_ack_ff = 0 ;
		end
		//write data
		else begin	// read slide 19 of Buses_Peripheral
			wb_vga_reg = (wb_vga_ack_ff && wb_m2s_vga_we) ? wb_m2s_vga_dat : wb_vga_reg;
			wb_vga_ack_ff = ! wb_vga_ack_ff & wb_m2s_vga_stb & wb_m2s_vga_cyc; 
		end
	end
	
	// read/display data
	assign wb_s2m_vga_ack = wb_vga_ack_ff;
	assign wb_s2m_vga_dat = wb_vga_reg;
	
endmodule