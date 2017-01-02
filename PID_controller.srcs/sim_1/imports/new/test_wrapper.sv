`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/20/2016 01:55:05 PM
// Design Name: 
// Module Name: wrapper
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


module test_wrapper
  #(
  parameter nData = 32,          // number of points per MAC, so total would be nMAC * nData
  parameter dataBitwidth = 16,
  parameter nMAC  = 50,
  parameter linCounterBW = 16,    //This is for simulation anddebugging
  parameter outputBW = dataBitwidth * 2
  )
   (
    output [outputBW - 1 : 0] debug
 
    );
    // total number of sample/ size of the sample array is
    // (nData * nMAC)
    // The total number of bits in the flatten array then 
    // is given by (nData * nMAC * dataBitwidth)
    localparam totalNBits = nData * dataBitwidth * nMAC;
    localparam totalNSamples = nData * nMAC;
    localparam nBits_MAC  = nData * dataBitwidth;
//-------------------End of parameters-----------------//

    
    
    
    reg   [totalNBits - 1 : 0]      flatCoeff;
//    reg   [dataBitwidth * nData - 1 : 0]  flatSample;
    reg   [outputBW * nMAC - 1 : 0] mac_out_storage;
    wire  [outputBW * nMAC - 1 : 0] mac_direct_out;
    wire   [outputBW - 1 : 0]       mac_sum;
    wire  [nMAC - 1: 0]             mac_armed;
    wire  [nMAC - 1: 0]             mac_done;
    wire                            sum_finished;
    wire                            sum_armed;
    reg   [linCounterBW - 1 : 0]    linCounter = 0;


    assign debug = mac_sum;
    
//------Clock generator for simulation-----------------//
    reg clk = 0;
    reg clk_mac;    
    always begin
      #5 clk <= ~clk;
    end
    
    assign clk_mac = clk;
    
//-----------Clock generator end-----------------------//


//-----------MAC output storage -----------------------//
//    reg mac_out_ready = 0;
    reg mac_out_storage_updated = 0;
    
    always @(posedge clk) begin    
      // Only update the MAC results if mac_done is 
      // flagged and the storage is not updated
      // storage_updated flag need to be reset somewhere
      if(mac_done && ~mac_out_storage_updated ) begin 
        mac_out_storage <= mac_direct_out;
//        mac_out_ready   <= 1;
        mac_out_storage_updated <= 1;
      end else if (sum_finished) begin
        mac_out_storage_updated <= 0;
      end
    end
//-----------MAC output storage end--------------------//

    
//------split mac_out for debug reason-----------------//
    genvar jj;
    wire  [outputBW - 1: 0] mac_out_split [0 : nMAC-1];
    generate  
      for(jj = 0; jj<nMAC; jj++) begin: debugsplit
        assign mac_out_split[jj] = mac_out_storage[jj * outputBW +: outputBW]; 
      end
    endgenerate
//------split mac_out for debug reason end-------------//


//    This is to populate the fixed array for coefficients
    integer i;
    initial begin
      clk <= 0;
      for (i = 0; i < totalNSamples; i ++) begin
        flatCoeff[i * dataBitwidth +: dataBitwidth] = 1;
      end
    end

//------Sampler----------------------------------------//
    reg   [totalNBits - 1 : 0]  flatSample = 0;
    reg sampled = 0;
    reg mac_1_rst = 0;
    wire  [dataBitwidth - 1 : 0]  newSample;
    wire rst_sampler = 0;
//  Making fakeData 
    assign newSample = linCounter + 3;
    
    always @(posedge clk) begin
      if(rst_sampler) begin
      end else if (&mac_armed & ~sampled) begin 
        linCounter <= linCounter + 1;
        flatSample <= {newSample, flatSample[totalNBits - 1 : dataBitwidth]};
        sampled <= 1;
      end else if (&mac_done) begin
        sampled <= 0;
      end
      

    end

//------Sampler end------------------------------------//    

//----Instantiate multiple MACs -----------------------//

    multiplyAccumulator 
      #(
        .nData(nData),
        .datBW(dataBitwidth), 
        .outBW(outputBW)
      ) MACs [nMAC-1 : 0]
        (
          .inA(flatCoeff),
          .inB(flatSample),
          .inputUpdated(sampled),
          .clk(clk_mac),
          .rst(1'b0),
          .mac_done(mac_done),
          .mac_armed(mac_armed),
          .mac_out(mac_direct_out)
        );
        
        
        
//----Instantiate multiple MACs end--------------------//

//------MAC sum----------------------------------------//
    
    serial_sum 
      #(
        .nMAC ( nMAC        ),
        .datBW( dataBitwidth),
        .outBW( outputBW    )
      ) 
      summer 
      (
        .mac_output(mac_out_storage),
        .inputUpdated(mac_out_storage_updated),
        .clk(clk_mac),
        .rst(0),
        .mac_sum(mac_sum),
        .sum_finished(sum_finished)
      );
//------MAC sum end------------------------------------//


endmodule    


// Backup some otherwise obsolete code 

//-------Create multiple arrays, each for a MAC--------//
//    wire   [nBits_MAC - 1 : 0] sampleSplit  [0 : nMAC-1];
//    wire   [nBits_MAC - 1 : 0] coeffSplit   [0 : nMAC-1];
//    wire   [outputBW - 1 : 0] mac_sum_split   [0 : nMAC-1];
//    genvar iMAC;
//    generate
//      for ( iMAC = 0; iMAC < nMAC; iMAC ++) begin : MACs_block
//        assign sampleSplit[iMAC] = flatSample[(iMAC+1) * nBits_MAC - 1 : iMAC * nBits_MAC];
//        assign coeffSplit[iMAC]  = flatCoeff[(iMAC+1) * nBits_MAC - 1 : iMAC * nBits_MAC];
//        assign mac_sum_split[iMAC]  = mac_out[(iMAC+1) * outputBW - 1 : iMAC * outputBW];
//      end
      
      
//    endgenerate
//-------Create multiple arrays, (each for a MAC) end--//


//------Multiply Accumulator reset counter-------------//

/* These are for generating clocks to clear the MAC, for
 * n MACs in parallel, they can use the same clear signal.
 */
//    reg [$clog2(nData) : 0] resetCounter = 0;
//    wire mac_rst;
//    assign mac_rst = (resetCounter == nData);
//    always @(posedge clk_mac) begin
//      if(mac_rst) begin
//        resetCounter <= 0;
//      end else begin
//        resetCounter <= resetCounter + 1;
//      end
//    end
//------Multiply Accumulator reset counter end---------//  
