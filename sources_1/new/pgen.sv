`timescale 1ns/1ps  //

module pgen (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [10:0] pkt_size,
    input  logic [1:0]  eth_type,
    input  logic [2:0]  n_pkt,
    input  logic [3:0]  ipg,

    input  logic        trig,

    input  logic [47:0] src_addr,
    input  logic [47:0] dst_addr,

    output logic [7:0]  tdata,
    output logic        tvalid,
    output logic        tlast,
    input  logic        tready
);

    typedef enum logic [2:0] {
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
    logic [1:0]  r_eth_type;
    logic [2:0]  r_n_pkt;
    logic [3:0]  r_ipg;

    logic [47:0] r_src_addr;
    logic [47:0] r_dst_addr;

    logic [10:0] payload_byte_cnt;
    logic [2:0]  pkt_cnt;
    logic [3:0]  ipg_cnt;
    logic [3:0]  cnt;

    // State register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            
            cnt               <= 0;

            r_pkt_size        <= 0;
            r_eth_type        <= 0;
            r_n_pkt           <= 0;
            r_ipg             <= 0;

            r_src_addr        <= 0;
            r_dst_addr        <= 0;

            payload_byte_cnt  <= 0;
            pkt_cnt           <= 0;
            ipg_cnt           <= 0;

            tdata             <= 0;
            tvalid            <= 0;
            tlast             <= 0;
        end
        else begin

            case (state)

                IDLE: begin
                    if (trig) begin
                        r_pkt_size <= pkt_size;
                        r_eth_type <= eth_type;
                        r_n_pkt    <= n_pkt;
                        r_ipg      <= ipg;

                        r_src_addr <= src_addr;
                        r_dst_addr <= dst_addr;

                        payload_byte_cnt <= 0;
                        pkt_cnt          <= 0;
                        ipg_cnt          <= 0;
                        cnt              <= 0;

                        tdata  <= 0;
                        tvalid <= 1;
                        tlast  <= 0;

                    end
                    else begin
                        r_pkt_size <= 0;
                        r_eth_type <= 0;
                        r_n_pkt    <= 0;
                        r_ipg      <= 0;

                        r_src_addr <= 0;
                        r_dst_addr <= 0;

                        payload_byte_cnt <= 0;
                        pkt_cnt          <= 0;
                        ipg_cnt          <= 0;
                        cnt              <= 0;

                        tdata  <= 0;
                        tvalid <= 0;
                        tlast  <= 0;
                    end
                end

                SEND_DST: begin
                    tdata  <= r_dst_addr[47 - 8*cnt -: 8];
                    tvalid <= 1;
                    if (tvalid && tready) begin
                    cnt    <= (cnt == 5) ? 0 : cnt + 1;
                    end
                end

                SEND_SRC: begin
                    tdata <= r_src_addr[47 - 8*cnt -: 8];
                    tvalid <= 1;
                    if (tvalid && tready) begin
                    cnt    <= (cnt == 5) ? 0 : cnt + 1;
                    end
                end

                SEND_ETHR_TYPE: begin
                    tdata <= 8'h10;
                    tvalid <= 1;
                    if (tvalid && tready) begin
                    cnt    <= (cnt == 1) ? 0 : cnt + 1;
                    end
                end

                SEND_PAYLOAD: begin
                    tdata  <= 8'hAA; // rand
                    tvalid <= 1;

                    if (tvalid && tready) begin
                    payload_byte_cnt    <= (payload_byte_cnt == r_pkt_size - 1) ? 0 : payload_byte_cnt + 1;
                    end

                    if (pkt_cnt == r_n_pkt) begin
                        tlast <= 1;
                    end
                    else begin
                        tlast <= 0;
                    end
                end

                IPG: begin
                    tvalid <= 0;
                    tlast <= 0;
                    ipg_cnt <= ipg_cnt + 1;
                end

                CLEANUP: begin
                    tvalid <= 0;
                    tlast  <= 0;
                end

            endcase
        end
    end

    always_comb begin
        next_state = state;

        case (state)

            IDLE: begin
                if (trig)
                    next_state = SEND_DST;
            end

            SEND_DST: begin
                if (cnt == 5)
                    next_state = SEND_SRC;
                else
                    next_state = SEND_DST;
            end

            SEND_SRC: begin
                if (cnt == 5)
                    next_state = SEND_ETHR_TYPE;
                else
                    next_state = SEND_SRC;
            end

            SEND_ETHR_TYPE: begin
                if (cnt == 1)
                    next_state = SEND_PAYLOAD;
                else
                    next_state = SEND_ETHR_TYPE;
            end

            SEND_PAYLOAD: begin

                if (payload_byte_cnt == r_pkt_size - 1) begin
                    next_state = IPG;
                end
                else begin
                    next_state = SEND_PAYLOAD;
                end

                if (pkt_cnt == r_n_pkt)
                    next_state = CLEANUP;
                else
                    next_state = SEND_PAYLOAD;
            end

            IPG: begin
                if (ipg_cnt == r_ipg)
                    next_state = SEND_PAYLOAD;
                else
                    next_state = IPG;
            end

            CLEANUP: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule