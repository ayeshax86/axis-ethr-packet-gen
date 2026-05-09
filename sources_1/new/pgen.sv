`timescale 1ns/1ps

module pgen (
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [10:0] pkt_size,
    input  logic [15:0] eth_type,
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

    typedef enum logic [3:0] {
        IDLE,
        LOAD,
        SEND_DST,
        SEND_SRC,
        SEND_ETHR_TYPE,
        SEND_PAYLOAD,
        IPG,
        CLEANUP
    } state_t;

    state_t state, next_state;

    logic [10:0] r_pkt_size;
    logic [15:0]  r_eth_type;
    logic [2:0]  r_n_pkt;
    logic [3:0]  r_ipg;

    logic [47:0] r_src_addr;
    logic [47:0] r_dst_addr;

    logic [10:0] payload_byte_cnt;
    logic [2:0]  pkt_cnt;
    logic [3:0]  ipg_cnt;
    logic [3:0]  cnt;
    logic        busy;
    logic        trig_accept;

    //========================================================
    // State register
    //========================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
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

                    if (tvalid && tready)                       
                        payload_byte_cnt <= (payload_byte_cnt == r_pkt_size-1) ? 0 : payload_byte_cnt + 1;

                    if (tvalid && tready && tlast)
                        pkt_cnt <= pkt_cnt + 1;

                end

                IPG: begin
                        ipg_cnt <= ipg_cnt + 1;
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
                if (trig)
                    next_state = SEND_DST;
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

                if (tvalid && tready && payload_byte_cnt == r_pkt_size-1) begin
                    if (pkt_cnt == r_n_pkt-1)
                        next_state = CLEANUP;
                    else
                        next_state = IPG;
                end
                else
                    next_state = SEND_PAYLOAD;

            end

            IPG: begin
                if (ipg_cnt == r_ipg)
                    next_state = SEND_DST;
                else
                    next_state = IPG;
            end

            CLEANUP: begin
                next_state = IDLE;
            end

        endcase
    end

    //========================================================
    // Output logic
    //========================================================
    always_comb begin

        case (state)

            IDLE: begin
                tdata  = 8'h00;
                tvalid = 1'b0;
                tlast  = 1'b0;
            end

            SEND_DST: begin
                tvalid = 1'b1;
                if (tvalid && tready) begin
                tdata  = r_dst_addr[47 - 8*cnt -: 8];
                tlast  = 1'b0;
                end
            end

            SEND_SRC: begin
                tdata  = r_src_addr[47 - 8*cnt -: 8];
                tvalid = 1'b1;
                tlast  = 1'b0;
            end

            SEND_ETHR_TYPE: begin
                tdata  = r_eth_type[15 - 8*cnt -: 8];
                tvalid = 1'b1;
                tlast  = 1'b0;
            end

            SEND_PAYLOAD: begin
                tvalid = 1'b1;
                
                if (tvalid && tready) begin
                tdata  = $urandom_range(0, 255);
                tvalid = 1'b1;

                if (payload_byte_cnt == r_pkt_size-1)
                    tlast = 1'b1;
                else
                    tlast = 1'b0;
                end
            end

            IPG: begin
                tdata  = 8'h00;
                tvalid = 1'b0;
                tlast  = 1'b0;
            end

            CLEANUP: begin
                tdata  = 8'h00;
                tvalid = 1'b0;
                tlast  = 1'b0;
            end

        endcase
    end

    assign busy = (state != IDLE);
    assign trig_accept = trig && !busy;

endmodule