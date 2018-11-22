module findblack(
  input clk, 
  input rst_n,
  input black_eval,
  input [3:0] sram_rdata,
  input [7:0] start_addr,
  input mode,
  output reg [7:0] sram_raddr,
  output reg [1:0] lo_idx, 
  output reg [7:0] lo_addr,
  output reg black_valid
);


//================= output control =================//
reg [7:0] lo_addr_next;
reg [1:0] lo_idx_next;
//================= FSM =================//
localparam IDLE = 3'd0, O1 = 3'd1, O2 = 3'd2, R1 = 3'd3, U1 = 3'd4;
reg [2:0] state, nstate;
reg black_find;
reg [3:0] sram_temp, sram_temp_;
//================= findblack =================//
//address counter
localparam RCNTWIDTH = 3;
wire [RCNTWIDTH-1:0] rcnt_out; 
reg rcnt_valid;

localparam DCNTWIDTH = 8;
wire [DCNTWIDTH-1:0] dcnt_out; 
reg dcnt_valid;

localparam BCNTWIDTH = 4;
wire [BCNTWIDTH-1:0] bcnt_out; 
reg bcnt_valid;
reg [7:0] temp;
reg [31:0] addr_temp;

// find upper_left corner information
reg [1:0] fb_idx_de;   // first_black pixel sram_idx




//================= FSM =================//
always@(posedge clk) begin
  if(~rst_n) state <= IDLE;
  else state <= nstate;
end

always@* begin
  case(state)
    IDLE: nstate = black_eval ? O1 : IDLE;
    O1: nstate = O2;
    O2: nstate = R1;
    R1: nstate = U1;
    U1: nstate = black_find ? IDLE : U1;
    default: nstate = IDLE;
  endcase
end

//================= output control =================//
always@(posedge clk) begin
  if(~rst_n) begin
    lo_addr <= 0;
    lo_idx <= 0;
  end
  else begin
    lo_addr <= lo_addr_next;
    lo_idx <= lo_idx_next;
  end
end

always@* begin 
  lo_idx_next = 0;
  if(state == U1) begin
    lo_idx_next = 0;
    if(black_find == 1) lo_idx_next = fb_idx_de;
  end
  else lo_idx_next = lo_idx;
end

always@* begin
  black_valid = black_find;
end

//================= findblack =================//
// address counter
counter
#(
  .DATA_WIDTH(RCNTWIDTH)
)
rcnt(
  .clk(clk),
  .rst_n(rst_n),
  .step(3'd1),
  .rst_val(3'd5),
  .cnt_valid(rcnt_valid),
  .cnt_out(rcnt_out) 
);

counter
#(
  .DATA_WIDTH(DCNTWIDTH)
)
dcnt(
  .clk(clk),
  .rst_n(rst_n),
  .step(8'd16),
  .rst_val(8'd85),
  .cnt_valid(dcnt_valid),
  .cnt_out(dcnt_out) 
);

dcounter
#(
  .DATA_WIDTH(BCNTWIDTH)
)
bcnt(
  .clk(clk),
  .rst_n(rst_n),
  .step(4'd1),
  .start_val(4'd10),
  .cnt_valid(bcnt_valid),
  .cnt_out(bcnt_out) 
);

always@* begin
  rcnt_valid = 0;
  dcnt_valid = 0;
  bcnt_valid = 0;
  if(state != IDLE) begin
    rcnt_valid = 1;
    if(mode == 1) bcnt_valid = 1;
    if(rcnt_out == 3'd5) begin
      dcnt_valid = 1;
    end
  end
end

always@* begin
  temp = 8'd0;
  if(mode == 0) begin
    temp[2:0] = rcnt_out;
    sram_raddr = temp + dcnt_out;
  end
  else begin
    temp[4:0] = bcnt_out;
    sram_raddr = start_addr + temp;
  end
  temp = start_addr;
  
  addr_temp = {sram_raddr, addr_temp[31:8]};
end

always@* begin
  sram_temp = 0;
  if(state == R1 | state == U1) sram_temp = sram_rdata;
  else sram_temp = sram_temp_;
end

// find upper_left corner information
always@(posedge clk) begin
  if(~rst_n) begin
    sram_temp_ <= 0;
  end 
  else begin
    sram_temp_ <= sram_temp;
  end
end

always@* begin 
  if(mode == 0) begin
    case(1)
      sram_temp_[0] == 1: fb_idx_de = 0;
      sram_temp_[1] == 1: fb_idx_de = 1;
      sram_temp_[2] == 1: fb_idx_de = 2;
      sram_temp_[3] == 1: fb_idx_de = 3;
      default: fb_idx_de = 0;
    endcase
  end
  else begin
    case(1)
      sram_temp_[1] == 1: fb_idx_de = 1;
      sram_temp_[0] == 1: fb_idx_de = 0;
      sram_temp_[3] == 1: fb_idx_de = 3;
      sram_temp_[2] == 1: fb_idx_de = 2;
      default: fb_idx_de = 0;
    endcase
  end
end


always@* begin 
  black_find = 0;
  if(state == U1) begin
    case(1)
      sram_temp_[0] == 1: black_find = 1;
      sram_temp_[1] == 1: black_find = 1;
      sram_temp_[2] == 1: black_find = 1;
      sram_temp_[3] == 1: black_find = 1;
      default: black_find = 0;
    endcase
  end
end

always@* begin 
  if(state == U1 | state == R1) begin
    if(black_find == 1) lo_addr_next = lo_addr;
    else lo_addr_next = addr_temp[14:8]; 
  end
  else lo_addr_next = lo_addr;
end





endmodule
