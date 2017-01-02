`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/02/2017 03:07:36 PM
// Design Name: 
// Module Name: memoryTest
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module memoryTest(

	input									clk_i			,
	input									rstn_i		,
  // System bus
  input      [ 32-1:0] sys_addr   ,  // bus address
  input      [ 32-1:0] sys_wdata  ,  // bus write data
  input      [  4-1:0] sys_sel    ,  // bus write byte select
  input                sys_wen    ,  // bus write enable
  input                sys_ren    ,  // bus read enable
  output reg [ 32-1:0] sys_rdata  ,  // bus read data
  output reg           sys_err    ,  // bus error indicator
  output reg           sys_ack       // bus acknowledge signal	
    );
	
localparam CW = 16; // 	Coefficient bitWidth
reg [ NC*CW -1: 0] coeffs = 0;

//---------------------------------------------------------------------------------
//
//  System bus connection

int i;

always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  coeffs <= {(NC*CW - 1) {1'b0}};
end else if (sys_wen) begin
	for (i=0; i < NC; i = i+1) begin
		if (sys_addr[19:0]== (20'h0 + i * 4))   coeffs[i * CW +: CW] <= sys_wdata[ CW-1 : 0];
	end
end

wire sys_en;
assign sys_en = sys_wen | sys_ren;

int j;
always @(posedge clk_i)
if (rstn_i == 1'b0) begin
  sys_err <= 1'b0;
  sys_ack <= 1'b0;
end else begin
  sys_err <= 1'b0;

  for (j=0; j < NC; j = j+1) begin
		if (sys_addr[19:0]== (20'h0 + j * 4)) begin
			sys_ack 	<= sys_en;
		  sys_rdata <= coeffs[j * CW +: CW] ;
		end
	end
  
end


endmodule
