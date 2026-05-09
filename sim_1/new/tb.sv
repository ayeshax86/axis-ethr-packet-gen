`timescale 1ns/1ps

<<<<<<< HEAD
module tb;
=======
module tb_pgen;
>>>>>>> 76158a32d630998cfda3b0d1fe178409715e3ecc

    logic        clk;
    logic        rst_n;

    logic [10:0] pkt_size;
<<<<<<< HEAD
    logic [15:0]  eth_type;
=======
    logic [1:0]  eth_type;
>>>>>>> 76158a32d630998cfda3b0d1fe178409715e3ecc
    logic [2:0]  n_pkt;
    logic [3:0]  ipg;

    logic        trig;

    logic [47:0] src_addr;
    logic [47:0] dst_addr;

    logic [7:0]  tdata;
    logic        tvalid;
    logic        tlast;
    logic        tready;

    pgen dut (
        .clk(clk),
        .rst_n(rst_n),

        .pkt_size(pkt_size),
        .eth_type(eth_type),
        .n_pkt(n_pkt),
        .ipg(ipg),

        .trig(trig),

        .src_addr(src_addr),
        .dst_addr(dst_addr),

        .tdata(tdata),
        .tvalid(tvalid),
        .tlast(tlast),
        .tready(tready)
    );

    always #5 clk = ~clk;

<<<<<<< HEAD

  
=======
>>>>>>> 76158a32d630998cfda3b0d1fe178409715e3ecc
    initial begin
        clk = 0;
        rst_n = 0;

<<<<<<< HEAD
        # 20;
        rst_n = 1;  
        tready = 1;

        pkt_size = 10'd10;
        eth_type = 15'hAB;
        n_pkt    = 3'd3;
        ipg      = 4'd12;

        trig = 1;

        src_addr = 48'hAABBCCDDEEFF;
        dst_addr = 48'h112233445566;

        #10 

        trig = 0;

       
        #50 trig =1;
        #10 trig = 0;
        
        
        
        
        
=======
        pkt_size = 0;
        eth_type = 0;
        n_pkt    = 0;
        ipg      = 0;

        trig     = 0;

        src_addr = 0;
        dst_addr = 0;

        tready   = 1;

        #20;
        rst_n = 1;

        #20;

        // same packet parameters
        pkt_size = 10;
        n_pkt    = 3;
        ipg      = 2;

        eth_type = 2'b00;

        src_addr = 48'h112233445566;
        dst_addr = 48'hAABBCCDDEEFF;

        // packet 1
        trig = 1;
        #10;
        trig = 0;

        #300;

        // packet 2
        trig = 1;
        #10;
        trig = 0;

        #300;

        // packet 3
        trig = 1;
        #10;
        trig = 0;

        #500;
>>>>>>> 76158a32d630998cfda3b0d1fe178409715e3ecc

        $finish;
    end

<<<<<<< HEAD
endmodule


=======
endmodule
>>>>>>> 76158a32d630998cfda3b0d1fe178409715e3ecc
