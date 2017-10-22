//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
// DUT

module MyDesign (

            //---------------------------------------------------------------------------
            // Control
            //
            output reg                  dut__xxx__finish   ,
            input  wire                 xxx__dut__go       ,  

            //---------------------------------------------------------------------------
            // b-vector memory 
            //
            output reg  [ 9:0]          dut__bvm__address  ,
            output wire                 dut__bvm__enable   ,
            output wire                 dut__bvm__write    ,
            output reg  [15:0]          dut__bvm__data     ,  // write data
            input  wire [15:0]          bvm__dut__data     ,  // read data
            
            //---------------------------------------------------------------------------
            // Input data memory 
            //
            output reg  [ 8:0]          dut__dim__address  ,
            output wire                 dut__dim__enable   ,
            output wire                 dut__dim__write    ,
            output reg  [15:0]          dut__dim__data     ,  // write data
            input  wire [15:0]          dim__dut__data     ,  // read data


            //---------------------------------------------------------------------------
            // Output data memory 
            //
            output reg  [ 2:0]          dut__dom__address  ,
            output reg  [15:0]          dut__dom__data     ,  // write data
            output wire                 dut__dom__enable   ,
            output reg                  dut__dom__write    ,


            //-------------------------------
            // General
            //
            input  wire                 clk             ,
            input  wire                 reset  

            );

  //---------------------------------------------------------------------------
  //
  //<<<<----  YOUR CODE HERE    ---->>>>
  //
  //`include "v564.vh"
  // 
  //---------------------------------------------------------------------------

  // Tie all enable, writes
  assign dut__bvm__enable = 1;
  assign dut__bvm__write  = 0;
  assign dut__dim__enable = 1;
  assign dut__dim__write  = 0;
  assign dut__dom__enable = 1;

  cnn u1( 
     .clock(clk), 
     .reset(reset), 
     .go(xxx__dut__go), 
     .finish(dut__xxx__finish), 
     .bvm_address(dut__bvm__address), 
     .dim_address(dut__dim__address), 
     .dim_data_unreg(dim__dut__data),
     .bvm_data_unreg(bvm__dut__data), 
     .dom_data(dut__dom__data), 
     .dom_address(dut__dom__address), 
     .dom_ready(dut__dom__write) 
  );


endmodule

