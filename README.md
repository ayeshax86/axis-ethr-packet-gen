// final code: default states added

`timescale 1ns / 1ps

module axis_stream_modifier #(
 parameter int DATA_W = 32,
 parameter int KEEP_W = DATA_W/8
) (
 input logic clk,
 input logic rst_n,
 // Control
 input logic [1:0] mode, // 00=pass, 01=drop, 10=swap, 11=append
 input logic [DATA_W-1:0] append_data, // word to append in mode 11
 // Slave AXI-Stream (input side)
 input logic [DATA_W-1:0] s_axis_tdata,
 input logic [KEEP_W-1:0] s_axis_tkeep,
 input logic s_axis_tvalid,
 output logic s_axis_tready,
 input logic s_axis_tlast,
 // Master AXI-Stream (output side)
 output logic [DATA_W-1:0] m_axis_tdata,
 output logic [KEEP_W-1:0] m_axis_tkeep,
 output logic m_axis_tvalid,
 input logic m_axis_tready,
 output logic m_axis_tlast
);
 
// provided

typedef enum logic [1:0] {
 ST_IDLE = 2'b00, // sends beats as they come
 ST_APPEND = 2'b01 // sends beats + appends one last beat
} state_t;
state_t state, state_n;

// Sequential block (provided -- do not modify)
always_ff @(posedge clk or negedge rst_n) begin
 if (!rst_n)
 state <= ST_IDLE;
 else
 state <= state_n;
end


logic [DATA_W-1:0] swap_data;
// TODO: Fill in the byte-swap logic.
// For a 32-bit word 0xAABBCCDD, swap_data should be 0xDDCCBBAA.
// Use a generate loop or always_comb with an integer iterator.

// always calculating swap data at every clk cycle but to use it
// or not is decided by user/ mode

always_comb begin
    state_n = state;

    swap_data[24 +: 8] = s_axis_tdata[0  +: 8];
    swap_data[16 +: 8] = s_axis_tdata[8  +: 8];
    swap_data[8  +: 8] = s_axis_tdata[16 +: 8];
    swap_data[0  +: 8] = s_axis_tdata[24 +: 8];

    
    // This logic is most commonly used when converting between Big-Endian and Little-Endian formats. 
    // In many FPGA protocols (like AXI4-Stream), the "first" byte is expected at the lowest bits, 
    // but if your data source treats the "first" byte as the most significant bits, you'll need this 
    // exact swap to make sense of the payload.
    
    m_axis_tdata  = 0; 
    m_axis_tkeep  = 0;
    m_axis_tvalid = 0;
    m_axis_tlast  = 0;
    s_axis_tready = 0; 

// All outputs always pulled to zero in case a state does not
// change a signal and it remians undefined by mistake. Otherwise a 
// latch would be inferred which is not good.
    
    case (state)
        ST_IDLE: begin
            if (mode == 2'b00) begin
                m_axis_tdata  = s_axis_tdata;
                m_axis_tkeep  = s_axis_tkeep;
                m_axis_tvalid = s_axis_tvalid;
                m_axis_tlast  = s_axis_tlast;
                s_axis_tready = m_axis_tready; 
            end
            
            else if (mode == 2'b01) begin // Drop
                s_axis_tready = 1'b1;
                // m_axis_tvalid = 0 because data is not valid as 
		// our mod dropped valid data
		// set by default when we pulled all signals zero 
            end 
            
            else if (mode == 2'b10) begin // Swap
                m_axis_tdata  = swap_data; // Use the reversed bytes
                m_axis_tkeep  = s_axis_tkeep;
                m_axis_tvalid = s_axis_tvalid;
                m_axis_tlast  = s_axis_tlast;
                s_axis_tready = m_axis_tready;
            end
            
            else if (mode == 2'b11) begin
                m_axis_tdata  = s_axis_tdata;
                m_axis_tkeep  = s_axis_tkeep;
                m_axis_tvalid = s_axis_tvalid;
                s_axis_tready = m_axis_tready;
                m_axis_tlast = 1'b0; 

		        // always forcing the last bit 0
                
                // confirm this beat is the last beat if not let it go 
                if (s_axis_tvalid && m_axis_tready && s_axis_tlast) begin
                    state_n = ST_APPEND;
                end
            end
        end // end mode 11

		        // when a beat comes with last bit = 1 we force it
                // to 0 (not last) then stall the bus for 1 cycle (because 1cycle               
                // is required to shift the fsm state from idle to apend state)
                // and in that one cycle add our APPEND bit at the end 
                // by sending it in that clock cycle
        
        ST_APPEND: begin
            m_axis_tdata  = append_data;  
            m_axis_tkeep  = '1; // set all bits to 1 regardless of width of bus       
            m_axis_tvalid = 1'b1;       
            m_axis_tlast  = 1'b1;        
            s_axis_tready = 1'b0;       

            if (m_axis_tready) begin
                state_n = ST_IDLE;    
            end else begin
                state_n = ST_APPEND;    
            end
        end
        default: state_n = ST_IDLE;
    endcase
end // end combin block

endmodule



/*
    for (int i = 0; i < KEEP_W; i++) begin
        // The byte starting at (i*8) in s_axis_tdata 
        // goes to the byte starting at ((KEEP_W-1-i)*8) in swap_data
        swap_data[(KEEP_W-1-i)*8 +: 8] = s_axis_tdata[i*8 +: 8]; // indexed part selector
    end
    */



/*
`timescale 1ns / 1ps

module axis_stream_modifier #(
    parameter int DATA_W = 32,
    parameter int KEEP_W = DATA_W/8
)(
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic [1:0]               mode,

    input  logic [DATA_W-1:0]        append_data,
    input  logic [DATA_W-1:0]        s_axis_tdata,
    input  logic [KEEP_W-1:0]        s_axis_tkeep,
    input  logic                     s_axis_tvalid,
    output logic                     s_axis_tready,
    input  logic                     s_axis_tlast,

    output logic [DATA_W-1:0]        m_axis_tdata,
    output logic [KEEP_W-1:0]        m_axis_tkeep,
    output logic                     m_axis_tvalid,
    input  logic                     m_axis_tready,
    output logic                     m_axis_tlast
);

typedef enum logic [1:0] {
    PASS,
    DROP,
    SWAP,
    APPEND
} state_t;

state_t state, next_state;

logic [1:0]          r_mode;
logic [DATA_W-1:0]   r_append_data;

logic [DATA_W-1:0]   ra_axis_tdata;
logic [KEEP_W-1:0]   ra_axis_tkeep;
logic                ra_axis_tvalid;
logic                ra_axis_tlast;

logic [DATA_W-1:0]   rb_axis_tdata;
logic [KEEP_W-1:0]   rb_axis_tkeep;
logic                rb_axis_tvalid;
logic                rb_axis_tlast;

logic                sel;

//========================================================
// State register
//========================================================
always_ff @(posedge clk or negedge rst_n) begin // state is a flop hence in always_ff
    if (!rst_n)
        state <= PASS;
    else
        state <= next_state;
end

always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

                sel <= 1'b0;
                s_axis_tready  <= 1'b0;

                ra_axis_tdata   <= 0;
                ra_axis_tkeep   <= 0;
                ra_axis_tvalid  <= 0;
                ra_axis_tlast   <= 0;
                rb_axis_tdata   <= 0;
                rb_axis_tkeep   <= 0;
                rb_axis_tvalid  <= 0;
                rb_axis_tlast   <= 0;
        
    end else begin
    case(state)

        PASS: begin

                sel <= 1'b0;
                s_axis_tready  <= 1'b1;

                ra_axis_tdata   <= 0;
                ra_axis_tkeep   <= 0;
                ra_axis_tvalid  <= 0;
                ra_axis_tlast   <= 0;
                rb_axis_tdata   <= 0;
                rb_axis_tkeep   <= 0;
                rb_axis_tvalid  <= 0;
                rb_axis_tlast   <= 0;

        end

        DROP: begin

                sel <= 1'b0;
                s_axis_tready  <= 1'b1;

                ra_axis_tdata   <= 0;
                ra_axis_tkeep   <= 0;
                ra_axis_tvalid  <= 0;
                ra_axis_tlast   <= 0;
                rb_axis_tdata   <= 0;
                rb_axis_tkeep   <= 0;
                rb_axis_tvalid  <= 0;
                rb_axis_tlast   <= 0;

        end

        SWAP: begin

                if (s_axis_tvalid && m_axis_tready) begin    
            
                sel <= ~sel;
                

                if (!sel) begin
                s_axis_tready   <= 1'b1;

                ra_axis_tdata   <= {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24]};
                ra_axis_tkeep   <= s_axis_tkeep;
                ra_axis_tvalid  <= s_axis_tvalid;
                ra_axis_tlast   <= s_axis_tlast;

                end else begin
                s_axis_tready   <= 1'b1;

                rb_axis_tdata   <= {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24]};
                rb_axis_tkeep   <= s_axis_tkeep;
                rb_axis_tvalid  <= s_axis_tvalid;
                rb_axis_tlast   <= s_axis_tlast;

                end
                end
        end


    endcase
    end

end

always_comb begin // for output signals
    case (state)

        PASS: begin
            m_axis_tdata   = s_axis_tdata;
            m_axis_tkeep   = s_axis_tkeep;
            m_axis_tvalid  = s_axis_tvalid;
            m_axis_tlast   = s_axis_tlast;

        end

        DROP: begin
            m_axis_tdata   = 0;
            m_axis_tkeep   = 0;
            m_axis_tvalid  = 0;
            m_axis_tlast   = 0;
            
        end

        SWAP: begin

            if (s_axis_tvalid && m_axis_tready) begin

            if (!sel) begin
            m_axis_tdata   = rb_axis_tdata;
            m_axis_tkeep   = rb_axis_tkeep;
            m_axis_tvalid  = rb_axis_tvalid;
            m_axis_tlast   = rb_axis_tlast;
            end else begin
            m_axis_tdata   = ra_axis_tdata;
            m_axis_tkeep   = ra_axis_tkeep;
            m_axis_tvalid  = ra_axis_tvalid;
            m_axis_tlast   = ra_axis_tlast;
            end
        end 
        end

        APPEND: begin

        end

    endcase
    
end


always_comb begin // next_state is a continuous signal hence in always_comb
    if (mode == PASS)
    next_state = PASS;
    else if (mode == DROP)
    next_state = DROP;
    else if (mode == SWAP)
    next_state = SWAP;
    else if (mode == APPEND)
    next_state = APPEND;
    else
    next_state = PASS;      
    
end

endmodule

*/
