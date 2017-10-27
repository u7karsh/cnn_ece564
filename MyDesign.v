//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
// DUT

module MyDesign (

            //---------------------------------------------------------------------------
            // Control
            //
            output wire                 dut__xxx__finish   ,
            input  wire                 xxx__dut__go       ,  

            //---------------------------------------------------------------------------
            // b-vector memory 
            //
            output wire  [ 9:0]         dut__bvm__address  ,
            output reg                  dut__bvm__enable   ,
            output reg                  dut__bvm__write    ,
            output wire [15:0]          dut__bvm__data     ,  // write data
            input  wire [15:0]          bvm__dut__data     ,  // read data
            
            //---------------------------------------------------------------------------
            // Input data memory 
            //
            output wire [ 8:0]          dut__dim__address  ,
            output reg                  dut__dim__enable   ,
            output reg                  dut__dim__write    ,
            output wire [15:0]          dut__dim__data     ,  // write data
            input  wire [15:0]          dim__dut__data     ,  // read data


            //---------------------------------------------------------------------------
            // Output data memory 
            //
            output wire [ 2:0]          dut__dom__address  ,
            output wire [15:0]          dut__dom__data     ,  // write data
            output reg                  dut__dom__enable   ,
            output wire                 dut__dom__write    ,


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
  always@(posedge clk) begin //{
     dut__bvm__enable <= 1;
     dut__bvm__write  <= 0;
     dut__dim__enable <= 1;
     dut__dim__write  <= 0;
     dut__dom__enable <= 1;
  end //}

  cnn  #(.ARCH_SELECTOR(1), .MULT_SQUEEZE(1))
  u1( 
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

