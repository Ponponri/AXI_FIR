`timescale 1ns / 1ps
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


    // write your code here!
    // 
    reg [(pDATA_WIDTH-1):0] ap;
    reg [(pDATA_WIDTH-1):0] count;
    reg run;
    reg [(pDATA_WIDTH-1):0] data_length;
    reg aw_en;
    reg [(pADDR_WIDTH-1):0] aw_addr;
    reg w_en;
    reg [(pDATA_WIDTH-1):0] w_data;
    reg ar_en;
    reg ar_valid, ar_ready;
    reg [(pADDR_WIDTH-1):0] ar_addr;
    reg r_en,ap_ren;
    reg r_ready, r_valid;
    reg [(pDATA_WIDTH-1):0] r_data;
    reg ss_we;
//    reg [(pADDR_WIDTH-1):0] fir_ptr;
    reg [(pADDR_WIDTH-1):0] timer;
    reg [(pADDR_WIDTH-1):0] data_current;
    reg [(pDATA_WIDTH-1):0] fir_multiple;
    reg [(pDATA_WIDTH-1):0] fir_psum;
    reg sm_re;
    //
    // ap 
    
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            ap <= 12'b0000_0000_0100;
        end
        else begin
            if(count > data_length+1) begin
                    ap <= 12'b0000_0000_0110;
            end
            else if(count > Tape_Num) begin
                    ap <= 12'b0000_0000_0000;
            end
            else if(aw_addr == 12'h00 && aw_en == 1 && ap[2] == 1'b1) begin
                if(wdata > 0) begin
                    ap <= 12'b0000_0000_0001;
                end
                else begin
                    ap <= ap;
                end
            end
            else begin
                ap <= ap;
            end
        end   
    end
    
    // run 
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            count <= 0;
            run <= 0;
        end
        else begin
            if(ap[0] == 1'b1 && run == 0) begin
//                ap[2] <= 1'b0;
                run <= 1;
            end
            else if(count > data_length+1) begin
                run <= 0; 
                count <= 1;
            end
            else if(run && (timer == 0)) begin
                count <= count + 1;
            end
            else begin
                count <= count;
            end
        end 
    end
    
    // data length
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            data_length <= 0;
        end
        else begin
        if(awaddr == 12'h10) begin
            data_length <= wdata;
        end
        else 
            data_length <= data_length;
        end
            
    end
    
    // axilite write addr  
    assign awready = awvalid;
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            aw_addr <= 0;
            aw_en <= 0;
        end
        else begin
            aw_addr <= awaddr;    
            if(awvalid && awready) begin
                aw_en <= 1;
            end
            else begin          
                aw_en <= 0;
            end
        end
    end
    
    // axilite write
    
    assign wready = wvalid;
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            w_data <= 0;
            w_en <= 0;
        end
        else begin
            w_data <= wdata;
            if (ar_addr == 12'h00) begin
                w_en <= 0;
            end
            else if(wvalid && wready) begin
                w_en <= 1;
            end
            else if(!r_en & !run)
                w_en <= 1;
            else
                w_en <= 0;
        end
    end
    
    // axilite read addr 
    assign arready = arvalid;
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            ar_valid <= 0;
            ar_ready <= 0;
            ar_addr <= 0;
            ar_en <= 0;
        end
        else begin
            ar_ready <= arready;
            ar_valid <= arvalid;
            ar_addr <= araddr;    
            if(arvalid && arready) begin
                ar_en <= 1;
            end
            else begin
                ar_en <= 0;
            end
        end
    end
    
    // axilite read
    assign rvalid = rready;
    assign rdata = (tap_Do & {pDATA_WIDTH{!ap_ren}}) | (ap & {pDATA_WIDTH{ap_ren}});
    always @(posedge axis_clk) begin
        if(!axis_rst_n) begin
            r_valid <= 0;
            r_ready <= 0;
            r_data <= 0;
            r_en <= 0;
            ap_ren <=0;
        end
        else begin
            r_valid <= rvalid;
            r_ready <= rready;
            r_data <= tap_Do;
            if(rready && rvalid && (ar_addr >= 12'h20)) begin
                r_en <= 1;
                ap_ren <= 0;
            end
            else if (ar_addr == 12'h00) begin
                ap_ren <= 1;
            end
            else begin
                r_en <= 0;
                ap_ren <= 0;
            end
        end
    end
    
    
    // tap bram control
    assign tap_A = ({pDATA_WIDTH{w_en}} & (awaddr-12'h20) ) | ({pDATA_WIDTH{r_en}} & (araddr-12'h20) | ({pDATA_WIDTH{ss_we}} & (timer%Tape_Num)*4)) ;
    assign tap_Di = wdata;
    assign tap_EN = 1;
    assign tap_WE = {4{w_en}};
    
    // ss 
    assign ss_tready = run && (timer == Tape_Num+1);
    always @(posedge axis_clk) begin 
        if(!axis_rst_n) begin
            ss_we <= 0;
        end
        else begin 
            if(ss_tready && ss_tvalid) begin
                ss_we <= 1;
            end
            else if(ss_tlast) begin
                ss_we <= 0;
            end
            else begin
                ss_we <= ss_we;
            end
        end        
    end
    
    // data bram control
    assign data_Di = ss_tdata;
    assign data_WE = {4{ss_we && (timer == 0)}};
    assign data_A = ({pDATA_WIDTH{ss_we}} & ((data_current - timer + Tape_Num-1) % Tape_Num )*4) ;
    assign data_EN = 1;
    
    // fir control 
    always @(posedge axis_clk) begin 
        if(!axis_rst_n) begin
//            fir_ptr <= 0;
            timer <= 0;
            data_current <= 0;
        end
        else begin
            timer <= (timer + 1) % (Tape_Num + 3);
            if(!run) begin 
                timer <= 0;
//                fir_ptr <= 0;
                data_current <= 0;
            end
            else if(timer == Tape_Num) begin
//                fir_ptr <= (fir_ptr + Tape_Num - 1) % Tape_Num; 
                data_current <= (data_current + 1) % Tape_Num;
            end
        end
    end
    
    // fir compute
    always @(posedge axis_clk) begin 
        if(!axis_rst_n) begin
            fir_multiple <= 0;
            fir_psum <= 0;
        end
        else begin
            if(timer == Tape_Num+2) begin
                fir_multiple <= 0;
                fir_psum <= 0;
            end
            else if (timer <= count && timer > 0) begin     
                fir_multiple <= tap_Do * data_Do;
                fir_psum <= fir_psum + fir_multiple;
            end
            else begin 
                fir_multiple <= fir_multiple;
                fir_psum <= fir_psum;
            end              
        end
    end
    
    // sm
    assign sm_tvalid = run && (timer == Tape_Num+1);
    assign sm_tlast = count == data_length+1;
    always @(posedge axis_clk) begin 
        if(!axis_rst_n) begin
            sm_re <= 0;
        end
        else begin 
            if(sm_tready && sm_tvalid) begin
                sm_re <= 1;
            end
            else if(ss_tlast) begin
                sm_re <= 0;
            end
            else begin
                sm_re <= sm_re;
            end
        end        
    end
    
    assign sm_tdata = {pDATA_WIDTH{sm_re}} & fir_psum;
//     assign sm_tdata = {pDATA_WIDTH{sm_re}} & count;
//    assign sm_tdata = {pDATA_WIDTH{sm_re}} & timer;
//    assign sm_tdata = {pDATA_WIDTH{sm_re}} & ap;
    
endmodule



























