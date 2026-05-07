`timescale 1ns/1ps

module tb_pgen;

    logic        clk;
    logic        rst_n;

    logic [10:0] pkt_size;
    logic [1:0]  eth_type;
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

    initial begin
        clk = 0;
        rst_n = 0;

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

        $finish;
    end

endmodule