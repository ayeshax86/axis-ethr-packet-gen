`timescale 1ns/1ps

module pkt_gen ( 
    input  logic        clk,
    input  logic        rst_n,

    input  logic        en,

    input  logic [10:0] pkt_size, // no. of bytes inside payload (42-1500)
    input  logic [15:0] eth_type, // 0x0800 for IvP4
    input  logic [15:0] n_pkt, // no. of packets sent to one address 
    input  logic [7:0]  ipg, // inter packet gap
    
    // EMAC IP will recognize the end of packet using last bit and valid being pulled low. Hence this
    // packet gap does not have to be equal to the ipg between two real ethernet packets. Just big enough.

    input  logic        trig, // used to latch values to the register

    input  logic [47:0] src_addr, // source MAC address of 6 bytes
    input  logic [47:0] dst_addr, // destination MAC address of 6 bytes

    output logic [7:0]  tdata, // m_axis signals
    output logic        tvalid,
    output logic        tlast,
    input  logic        tready
);

    typedef enum logic [3:0] {
        IDLE,
        SEND_DST,
        SEND_SRC,
        SEND_ETHR_TYPE,
        SEND_PAYLOAD,
        IPG,
        CLEANUP
    } state_t;

    state_t state, next_state;

    logic [10:0] r_pkt_size;
    logic [15:0] r_eth_type;
    logic [15:0] r_n_pkt;
    logic [7:0]  r_ipg;

    logic [47:0] r_src_addr;
    logic [47:0] r_dst_addr;

    logic [10:0] payload_byte_cnt;
    logic [15:0] pkt_cnt;
    logic [7:0]  ipg_cnt;
    logic [3:0]  cnt;

    logic        busy; // trig is ignored until tx is busy

    logic [7:0]  lfsr; // Linear Feedback Shift Register to generate random numbers

    logic trig_d; // detect the rising edge of trig 
    logic trig_pulse; // generate a 1 clk signal pulse on detection

    //========================================================
    // State register
    //========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else if (!en)
            state <= IDLE;
        else
            state <= next_state;
    end

    //========================================================
    // Sequential logic
    //========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            cnt              <= 0;

            r_pkt_size       <= 0;
            r_eth_type       <= 0;
            r_n_pkt          <= 0;
            r_ipg            <= 0;

            r_src_addr       <= 0;
            r_dst_addr       <= 0;

            payload_byte_cnt <= 0;
            pkt_cnt          <= 0;
            ipg_cnt          <= 0;

        end
        else begin

            case (state)

                IDLE: begin
                    if (en && trig_pulse) begin
                        r_pkt_size       <= pkt_size;
                        r_eth_type       <= eth_type;
                        r_n_pkt          <= n_pkt;
                        r_ipg            <= ipg;

                        r_src_addr       <= src_addr;
                        r_dst_addr       <= dst_addr;

                        payload_byte_cnt <= 0;
                        pkt_cnt          <= 0;
                        ipg_cnt          <= 0;
                        cnt              <= 0;
                    end
                    else begin
                        r_pkt_size       <= 0;
                        r_eth_type       <= 0;
                        r_n_pkt          <= 0;
                        r_ipg            <= 0;

                        r_src_addr       <= 0;
                        r_dst_addr       <= 0;

                        payload_byte_cnt <= 0;
                        pkt_cnt          <= 0;
                        ipg_cnt          <= 0;
                        cnt              <= 0;
                    end
                end

                SEND_DST: begin
                    if (tvalid && tready)
                        cnt <= (cnt == 5) ? 0 : cnt + 1;
                end

                SEND_SRC: begin
                    if (tvalid && tready)
                        cnt <= (cnt == 5) ? 0 : cnt + 1;
                end

                SEND_ETHR_TYPE: begin
                    if (tvalid && tready)
                        cnt <= (cnt == 1) ? 0 : cnt + 1;
                end

                SEND_PAYLOAD: begin

                    if (tvalid && tready) begin
                        payload_byte_cnt <=
                            (payload_byte_cnt == r_pkt_size - 1)
                                ? 0
                                : payload_byte_cnt + 1;
                    end

                    if (tvalid && tready && tlast) begin
                        pkt_cnt <= pkt_cnt + 1;
                    end

                end

                IPG: begin
                    ipg_cnt <= (ipg_cnt == r_ipg - 1) ? 0 : ipg_cnt + 1;
                end

                CLEANUP: begin
                    cnt              <= 0;

                    r_pkt_size       <= 0;
                    r_eth_type       <= 0;
                    r_n_pkt          <= 0;
                    r_ipg            <= 0;

                    r_src_addr       <= 0;
                    r_dst_addr       <= 0;

                    payload_byte_cnt <= 0;
                    pkt_cnt          <= 0;
                    ipg_cnt          <= 0;
                end

                default: begin
                    cnt              <= 0;

                    r_pkt_size       <= 0;
                    r_eth_type       <= 0;
                    r_n_pkt          <= 0;
                    r_ipg            <= 0;

                    r_src_addr       <= 0;
                    r_dst_addr       <= 0;

                    payload_byte_cnt <= 0;
                    pkt_cnt          <= 0;
                    ipg_cnt          <= 0;
                end

            endcase
        end
    end

    //========================================================
    // Next-state logic
    //========================================================
    always_comb begin

        next_state = state;

        case (state)

            IDLE: begin
                if (en && trig_pulse)
                    next_state = SEND_DST;
                else
                    next_state = IDLE;
            end

            SEND_DST: begin
                if (tvalid && tready && cnt == 5)
                    next_state = SEND_SRC;
                else
                    next_state = SEND_DST;
            end

            SEND_SRC: begin
                if (tvalid && tready && cnt == 5)
                    next_state = SEND_ETHR_TYPE;
                else
                    next_state = SEND_SRC;
            end

            SEND_ETHR_TYPE: begin
                if (tvalid && tready && cnt == 1)
                    next_state = SEND_PAYLOAD;
                else
                    next_state = SEND_ETHR_TYPE;
            end

            SEND_PAYLOAD: begin
                if (tvalid && tready &&
                    payload_byte_cnt == r_pkt_size - 1) begin

                    if (pkt_cnt == r_n_pkt - 1)
                        next_state = CLEANUP;
                    else
                        next_state = IPG;
                end
                else begin
                    next_state = SEND_PAYLOAD;
                end
            end

            IPG: begin
                if (ipg_cnt == r_ipg - 1)
                    next_state = SEND_DST;
                else
                    next_state = IPG;
            end

            CLEANUP: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    //========================================================
    // Output logic
    //========================================================
    always_comb begin

        tdata  = 8'h00;
        tvalid = 1'b0;
        tlast  = 1'b0;

        case (state)

            IDLE: begin
            end

            SEND_DST: begin
                tvalid = 1'b1;
                tdata  = r_dst_addr[47 - 8 * cnt -: 8];
            end

            SEND_SRC: begin
                tvalid = 1'b1;
                tdata  = r_src_addr[47 - 8 * cnt -: 8];
            end

            SEND_ETHR_TYPE: begin
                tvalid = 1'b1;
                tdata  = r_eth_type[15 - 8 * cnt -: 8];
            end

            SEND_PAYLOAD: begin
                tvalid = 1'b1;
                tdata  = lfsr;

                if (payload_byte_cnt == r_pkt_size - 1)
                    tlast = 1'b1;
            end

            IPG: begin
            end

            CLEANUP: begin
            end

            default: begin
                tdata  = 8'h00;
                tvalid = 1'b0;
                tlast  = 1'b0;
            end

        endcase
    end

    assign busy = (state != IDLE);

    //========================================================
    // LFSR
    //========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            lfsr <= 8'hAB;
        else if (state == SEND_PAYLOAD && tvalid && tready)
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            trig_d <= 1'b0;
        else
            trig_d <= trig;
    end

    assign trig_pulse = trig & ~trig_d;
    
    
    ila_0 my_ila (
	.clk(clk), // input wire clk


	.probe0(pkt_size), // input wire [10:0]  probe0  
	.probe1(eth_type), // input wire [15:0]  probe1 
	.probe2(n_pkt), // input wire [15:0]  probe2 
	.probe3(ipg), // input wire [3:0]  probe3 
	.probe4(trig), // input wire [0:0]  probe4 
	.probe5(src_addr), // input wire [47:0]  probe5 
	.probe6(dst_addr), // input wire [47:0]  probe6 
	.probe7(tdata), // input wire [7:0]  probe7 
	.probe8(tvalid), // input wire [0:0]  probe8 
	.probe9(tlast), // input wire [0:0]  probe9 
	.probe10(tready), // input wire [0:0]  probe10 
	.probe11(r_pkt_size), // input wire [10:0]  probe11 
	.probe12(r_eth_type), // input wire [15:0]  probe12 
	.probe13(r_n_pkt), // input wire [15:0]  probe13 
	.probe14(r_ipg), // input wire [3:0]  probe14 
	.probe15(r_src_addr), // input wire [47:0]  probe15 
	.probe16(r_dst_addr), // input wire [47:0]  probe16 
	.probe17(payload_byte_cnt), // input wire [10:0]  probe17 
	.probe18(pkt_cnt), // input wire [15:0]  probe18 
	.probe19(ipg_cnt), // input wire [3:0]  probe19 
	.probe20(cnt), // input wire [3:0]  probe20 
	.probe21(busy), // input wire [0:0]  probe21 
	.probe22(lfsr), // input wire [7:0]  probe22 
	.probe23(trig_d), // input wire [0:0]  probe23 
	.probe24(trig_pulse), // input wire [0:0]  probe24 
	.probe25(state) // input wire [0:0]  probe25 
	//.probe26(probe26), // input wire [0:0]  probe26 
	//.probe27(probe27), // input wire [0:0]  probe27 
	//.probe28(probe28), // input wire [0:0]  probe28 
	//.probe29(probe29) // input wire [0:0]  probe29
);
  
  
    

endmodule




