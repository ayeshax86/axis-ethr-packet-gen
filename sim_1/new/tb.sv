`timescale 1ns/1ps

module tb;

    logic        clk;
    logic        rst_n;

    logic [10:0] pkt_size;
    logic [15:0]  eth_type;
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

        # 20;
        rst_n = 1;  
        tready = 1;

        pkt_size = 10'd10;
        eth_type = 15'hAB;
        n_pkt    = 3'd3;
        ipg      = 4'd12;
        src_addr = 48'hAABBCCDDEEFF;
        dst_addr = 48'h112233445566;
        
        

        trig = 1;
        #10
        
        tready = 0;
        #30
        
        tready = 1;

        #60 
        
        tready = 0;
        #10
        
        tready = 1;
        #10
        
        tready = 0;
        #20
        
        tready = 1;
        #60
        tready = 0;
        #20
        
        tready = 1;
        
        # 30
        
        
         tready = 0;
        #20
        tready = 1;
        
        
        #30
        
        tready = 0;
        #20
        tready = 1;
        
        
        #200
        

        $finish;//
    end

endmodule

/*
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/USERNAME/REPO.git
git branch -M main
git push -u origin main

git add .
git commit -m "Updated files"
git push

# Useful checks
git status
git log --oneline
git remote -v
*/