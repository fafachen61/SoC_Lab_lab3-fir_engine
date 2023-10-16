module fir 
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,

    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,    

    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 

    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);
begin

    reg tap_EN_w, tap_EN_r;
    reg [3:0] data_WE_w, data_WE_r, tap_WE_r, tap_WE_w;
    reg [(pDATA_WIDTH-1):0] data_Di_w, data_Di_r;
    reg [(pADDR_WIDTH-1):0] data_A_w, data_A_r, tap_A_w, tap_A_r;
    reg tap_switch_r, tap_switch_w;
    reg [(pDATA_WIDTH-1):0] axi_lite_config_r, axi_lite_config_w;
    
    // write your code here!
    reg awready_w, awready_r, wready_w, wready_r, arready_w, arready_r;
    reg rvalid_w, rvalid_r;
    reg [(pDATA_WIDTH-1):0] rdata_w, rdata_r;

    reg signed [(pDATA_WIDTH-1):0] result_w, result_r;
    reg [3:0] calc_count_w, calc_count_r, calc_count_target_w, calc_count_target_r;
    reg [(pADDR_WIDTH-1):0] calc_tap_start_addr_w, calc_tap_start_addr_r;
    reg [(pADDR_WIDTH-1):0] data_update_addr_record_w, data_update_addr_record_r;
    reg stop_process_w, stop_process_r;
    reg final_stage_flag_w, final_stage_flag_r, initialize_stage_flag_w, initialize_stage_flag_r;

    reg ss_tready_w, ss_tready_r;
    reg sm_tvalid_w, sm_tvalid_r, sm_tlast_w, sm_tlast_r;
    reg [(pDATA_WIDTH-1):0] sm_tdata_w, sm_tdata_r;

   
    assign wready = 1'b1;
    // TAP RAM
    assign tap_WE = (tap_switch_r)? tap_WE_r : (awvalid)? 4'b1111 : 4'b0000;
    assign tap_EN = tap_EN_r;
    assign tap_Di = wdata;
    assign tap_A = (tap_switch_r)? tap_A_r : (awvalid && awaddr>=32)? (awaddr-32) : (awvalid)? awaddr : (araddr>=32)? (araddr-32) : araddr;
    assign rdata = (initialize_stage_flag_r)? tap_Do : axi_lite_config_r;
    // DATA RAM
    assign data_WE = data_WE_r;
    assign data_EN = 1;
    assign data_Di = ss_tdata;
    assign data_A = data_A_r;

    assign awready  = awready_r;
    assign wready   = 1;
    assign arready  = arready_r;
    assign rvalid   = rvalid_r;
    assign ss_tready    = axis_rst_n? ss_tready_r:0;
    assign sm_tvalid    = sm_tvalid_r;
    assign sm_tdata     = result_r;
    assign sm_tlast     = sm_tlast_r;

    reg [3:0] state_w, state_r;
    parameter IDLE          =   4'b0000;
    parameter STORE_DATA    =   4'b0001;
    parameter SEND_DATA     =   4'b0010;
    parameter RAISE_READY   =   4'b0011;
    parameter WAIT_TAP1     =   4'b0100;
    parameter WAIT_TAP2     =   4'b0101;
    parameter FILL_BRAM     =   4'b0110;
    parameter CALC_STAGE    =   4'b0111;
    parameter CALC_PREPARE  =   4'b1000;
    parameter RESET_CALC    =   4'b1001;
    parameter UPDATA_DATA   =   4'b1010;
    parameter FINAL_STAGE   =   4'b1011;

    always @(*) begin
        rvalid_w = rvalid_r;
        if(arvalid) begin
            rvalid_w = 1;
        end
        else begin
            rvalid_w = 0;
        end
    end

    always @(*) begin
        ss_tready_w = 0;
        result_w = result_r;
        sm_tvalid_w = 0;
        data_A_w = data_A_r;
        data_WE_w = data_WE_r;
        tap_EN_w = tap_EN_r;
        tap_A_w = tap_A_r;
        tap_WE_w = tap_WE_r;
        tap_switch_w = tap_switch_r;
        calc_count_w = calc_count_r;
        calc_count_target_w = calc_count_target_r;
        data_update_addr_record_w = data_update_addr_record_r;
        stop_process_w = stop_process_r;
        final_stage_flag_w = final_stage_flag_r;
        initialize_stage_flag_w = initialize_stage_flag_r;
        axi_lite_config_w = axi_lite_config_r;
        case (state_r)
            WAIT_TAP2 : begin
              if(tap_A == 12'h28) begin
                data_WE_w = 4'b1111;
                data_A_w = 12'h0;
                tap_EN_w = 0;
                ss_tready_w = 1'b1;
              end
            end
            FILL_BRAM : begin
              if(data_A_r == 12'h28) begin
                ss_tready_w = 1'b0;
                data_A_w = 12'h0;
                data_WE_w = 4'b0000;
                tap_A_w = calc_count_target_r << 2;
                tap_WE_w = 4'b0000;
                tap_switch_w = 1;
                tap_EN_w = 1;
              end
              else begin
                tap_EN_w = 0;
                ss_tready_w = 1'b1;
                data_WE_w = 4'b1111;
                data_A_w = data_A_r + 4;
              end
            end
            RESET_CALC : begin
              data_WE_w = 4'b0000;
              data_A_w = (calc_count_target_r == 4'd11)? data_update_addr_record_r : 0;
              tap_A_w = (calc_count_target_r == 4'd11)? 12'h28 : calc_count_target_r<< 2;
            end
            CALC_PREPARE : begin
              result_w = 0;
              data_A_w = (data_A_r == 12'h28)? 12'h00 : data_A_r + 4;
              tap_A_w = tap_A_r - 4;
              calc_count_w = 1;
              calc_count_target_w = (calc_count_target_r == 4'd11)? calc_count_target_r : calc_count_target_r + 1;
              stop_process_w = (ss_tlast)? 1 : 0;
              initialize_stage_flag_w = 0;
              axi_lite_config_w[0] = 0;
            end
            CALC_STAGE : begin
              result_w = result_r + data_Do * tap_Do;
              if(tap_A_r !== 12'h28) tap_A_w = tap_A_r - 4;
              data_A_w = (data_A_r == 12'h28)? 12'h00 : data_A_r + 4;
              calc_count_w = calc_count_r + 1;
            end
            UPDATA_DATA: begin
              ss_tready_w = 1'b1;
              data_WE_w = 4'b1111;
              data_A_w = data_update_addr_record_r;//data_A_r + 4;
              data_update_addr_record_w = (data_update_addr_record_r == 12'h28)? 12'h00 : data_update_addr_record_r + 4;
            end
            SEND_DATA : begin
              data_WE_w = 4'b0000;
              sm_tvalid_w = 1'b1;
            end
            FINAL_STAGE : begin
              final_stage_flag_w = 1;
              axi_lite_config_w[2:1] = 2'b11;
            end
        endcase
    end

    always @(*) begin
        state_w = state_r;
        case (state_r)
            IDLE :          state_w = WAIT_TAP1;
            WAIT_TAP1 :     state_w = (~awvalid)? WAIT_TAP1 : (tap_A == 12'h28)? WAIT_TAP2 : WAIT_TAP1;
            WAIT_TAP2 :     state_w = (~arvalid)? WAIT_TAP2 : (tap_A == 12'h28)? FILL_BRAM : WAIT_TAP2;
            FILL_BRAM :     state_w = (data_A_r == 12'h28)? CALC_PREPARE : FILL_BRAM;
            CALC_PREPARE :  state_w = CALC_STAGE;
            CALC_STAGE:     state_w = (calc_count_r == calc_count_target_r)? SEND_DATA: CALC_STAGE;
            SEND_DATA  :    state_w = (stop_process_r)? FINAL_STAGE : (calc_count_target_r == 11)? UPDATA_DATA : RESET_CALC; 
            RESET_CALC :    state_w = CALC_PREPARE;
            UPDATA_DATA:    state_w = RESET_CALC;
        endcase
    end

    always@(posedge axis_clk) begin
        if (!axis_rst_n) begin
            state_r <= IDLE;
            awready_r <= 0;
            wready_r <= 0;
            arready_r <= 0;
            rvalid_r <= 0;
            rdata_r <= 0;
            ss_tready_r <= 0;
            sm_tvalid_r <= 0;
            sm_tdata_r <= 0;
            sm_tlast_r <= 0;
            data_A_r <= 0;
            data_WE_r <= 0;
            tap_EN_r <= 1;
            tap_A_r <= 0;
            tap_WE_r <= 0;
            tap_switch_r <= 0;
            result_r <= 0;
            calc_count_r <= 0;
            calc_count_target_r <= 0;
            data_update_addr_record_r <= 0;
            stop_process_r <= 0;
            final_stage_flag_r <= 0;
            initialize_stage_flag_r <= 1;
            axi_lite_config_r <= 0;
        end else begin
            state_r <= state_w;
            awready_r <= awready_w;
            wready_r <= wready_w;
            arready_r <= arready_w;
            rvalid_r <= rvalid_w;
            rdata_r <= rdata_w;
            ss_tready_r <= ss_tready_w;
            sm_tvalid_r <= sm_tvalid_w;
            sm_tdata_r <= sm_tdata_w;
            sm_tlast_r <= sm_tlast_w;
            data_A_r <= data_A_w;
            data_WE_r <= data_WE_w;
            tap_EN_r <= tap_EN_w;
            tap_A_r <= tap_A_w;
            tap_WE_r <= tap_WE_w;
            tap_switch_r <= tap_switch_w;
            result_r <= result_w;
            calc_count_r <= calc_count_w;
            calc_count_target_r <= calc_count_target_w;
            data_update_addr_record_r <= data_update_addr_record_w;
            stop_process_r <= stop_process_w;
            final_stage_flag_r <= final_stage_flag_w;
            initialize_stage_flag_r <= initialize_stage_flag_w;
            axi_lite_config_r <= axi_lite_config_w;
        end
    end

end
endmodule