module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

integer i;

reg [13:0] position;
reg row_sel;
reg col_sel;
reg [7:0] kernel[0:8];
reg [3:0]counter;

reg[8:0]cal1,cal2;
reg[9:0]cal3,cal4;
reg[7:0]cal5,cal6;

wire [6:0] x_add,x_minus,y_add,y_minus;
assign x_add = position[13:7] + 7'd1;
assign x_minus = position[13:7] - 7'd1;
assign y_add = position[6:0] + 7'd1;
assign y_minus = position[6:0] - 7'd1;

parameter
read = 0,
init = 1,
get_9pix = 2,
calculation = 3,
op = 4,
finish = 5;

reg [2:0] current_state, next_state;

always@(posedge clk or posedge reset)
begin
	if(reset)
		current_state <= read;
	else
		current_state <= next_state;
end

always@(*)
begin
    case (current_state)
        read: 
        begin
            if(position==14'd16383)
                next_state = init;
            else
                next_state = read;
        end 
        init: next_state = get_9pix;
        get_9pix:
        begin
            if(counter == 4'd9)
                next_state = calculation;
            else
                next_state = get_9pix;
        end
        calculation: next_state = op;
        op:
        begin
            if(position == 14'd16382)
                next_state = finish;
            else
                next_state = get_9pix;
        end
        
        finish: next_state = read;
        default: next_state = read;
    endcase
end

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        done <= 1'b0;

        wr_r <= 1'b0;
        addr_r <= 14'd0;
        wdata_r <= 8'd0;

        wr_g <= 1'b0;
        addr_g <= 14'd0;
        wdata_g <= 8'd0;

        wr_b <= 1'b0;
        addr_b <= 14'd0;
        wdata_b <= 8'd0;

        row_sel <= 1'd1;
        col_sel <= 1'd0;
        position <= 14'd0;
        counter <= 4'd0;
        for(i=0;i<9;i=i+1)
            kernel[i] <= 8'd0;

        cal1 <= 9'd0;
        cal2 <= 9'd0;
        cal3 <= 10'd0;
        cal4 <= 10'd0;
    end
    else
    begin
        case (current_state)
            read: 
            begin
                position <= position + 14'd1;
                if(position[6:0] == 7'b1111111)
                    row_sel <= ~row_sel;
                col_sel <= ~col_sel;
                case ({row_sel, col_sel})
                    2'b00://even B
                    begin
                        wr_b <= 1'b1;
                        addr_b <= position;
                        wdata_b <= data_in;
                    end
                    2'b01://even G
                    begin
                        wr_g <= 1'b1;
                        addr_g <= position;
                        wdata_g <= data_in;
                    end
                    2'b10://odd G
                    begin
                        wr_g <= 1'b1;
                        addr_g <= position;
                        wdata_g <= data_in;
                    end
                    2'b11://odd R
                    begin
                        wr_r <= 1'b1;
                        addr_r <= position;
                        wdata_r <= data_in;
                    end
                endcase
            end

            init:
            begin
                position[13:7] <= 7'd1;
                position[6:0] <= 7'd1;
                row_sel <= 1'b0;
                col_sel <= 1'b1;
                wr_g <= 1'b0;
                wr_b <= 1'b0;
                wr_r <= 1'b0;
            end

            get_9pix:
            begin
                wr_g <= 1'b0;
                wr_b <= 1'b0;
                wr_r <= 1'b0;
                counter <= counter + 4'd1;
                if(counter < 4'd9)//get next value
                begin
                    case ({row_sel, col_sel})
                        2'b00://2
                        begin
                            case (counter)
                                4'd0: addr_r <= {x_minus,y_minus};
                                4'd1: addr_g <= {x_minus,position[6:0]};
                                4'd2: addr_r <= {x_minus, y_add};
                                4'd3: addr_g <= {position[13:7],y_minus};
                                4'd4: addr_b <= position;
                                4'd5: addr_g <= {position[13:7],y_add};
                                4'd6: addr_r <= {x_add, y_minus};
                                4'd7: addr_g <= {x_add, position[6:0]};
                                4'd8: addr_r <= {x_add, y_add};
                            endcase
                        end
                        2'b01://1
                        begin
                            case (counter)
                                4'd0: addr_g <= {x_minus,y_minus};
                                4'd1: addr_r <= {x_minus,position[6:0]};
                                4'd2: addr_g <= {x_minus, y_add};
                                4'd3: addr_b <= {position[13:7],y_minus};
                                4'd4: addr_g <= position;
                                4'd5: addr_b <= {position[13:7],y_add};
                                4'd6: addr_g <= {x_add, y_minus};
                                4'd7: addr_r <= {x_add, position[6:0]};
                                4'd8: addr_g <= {x_add, y_add};
                            endcase
                        end
                        2'b10://4
                        begin
                            case (counter)
                                4'd0: addr_g <= {x_minus,y_minus};
                                4'd1: addr_b <= {x_minus,position[6:0]};
                                4'd2: addr_g <= {x_minus, y_add};
                                4'd3: addr_r <= {position[13:7],y_minus};
                                4'd4: addr_g <= position;
                                4'd5: addr_r <= {position[13:7],y_add};
                                4'd6: addr_g <= {x_add, y_minus};
                                4'd7: addr_b <= {x_add, position[6:0]};
                                4'd8: addr_g <= {x_add, y_add};
                            endcase
                        end
                        2'b11://3
                        begin
                            case (counter)
                                4'd0: addr_b <= {x_minus,y_minus};
                                4'd1: addr_g <= {x_minus,position[6:0]};
                                4'd2: addr_b <= {x_minus, y_add};
                                4'd3: addr_g <= {position[13:7],y_minus};
                                4'd4: addr_r <= position;
                                4'd5: addr_g <= {position[13:7],y_add};
                                4'd6: addr_b <= {x_add, y_minus};
                                4'd7: addr_g <= {x_add, position[6:0]};
                                4'd8: addr_b <= {x_add, y_add};
                            endcase
                        end
                    endcase
                end
                //store current value
                if(counter > 4'd0)
                begin
                    case ({row_sel, col_sel})
                        2'b00://2
                        begin
                            case (counter)
                                4'd1: kernel[counter-1] <= rdata_r;
                                4'd2: kernel[counter-1] <= rdata_g;
                                4'd3: kernel[counter-1] <= rdata_r;
                                4'd4: kernel[counter-1] <= rdata_g;
                                4'd5: kernel[counter-1] <= rdata_b;
                                4'd6: kernel[counter-1] <= rdata_g;
                                4'd7: kernel[counter-1] <= rdata_r;
                                4'd8: kernel[counter-1] <= rdata_g;
                                4'd9: kernel[counter-1] <= rdata_r;
                            endcase
                        end
                        2'b01://1
                        begin
                            case (counter)
                                4'd1: kernel[counter-1] <= rdata_g;
                                4'd2: kernel[counter-1] <= rdata_r;
                                4'd3: kernel[counter-1] <= rdata_g;
                                4'd4: kernel[counter-1] <= rdata_b;
                                4'd5: kernel[counter-1] <= rdata_g;
                                4'd6: kernel[counter-1] <= rdata_b;
                                4'd7: kernel[counter-1] <= rdata_g;
                                4'd8: kernel[counter-1] <= rdata_r;
                                4'd9: kernel[counter-1] <= rdata_g;
                            endcase
                        end
                        2'b10://4
                        begin
                            case (counter)
                                4'd1: kernel[counter-1] <= rdata_g;
                                4'd2: kernel[counter-1] <= rdata_b;
                                4'd3: kernel[counter-1] <= rdata_g;
                                4'd4: kernel[counter-1] <= rdata_r;
                                4'd5: kernel[counter-1] <= rdata_g;
                                4'd6: kernel[counter-1] <= rdata_r;
                                4'd7: kernel[counter-1] <= rdata_g;
                                4'd8: kernel[counter-1] <= rdata_b;
                                4'd9: kernel[counter-1] <= rdata_g;
                            endcase
                        end
                        2'b11://3
                        begin
                            case (counter)
                                4'd1: kernel[counter-1] <= rdata_b;
                                4'd2: kernel[counter-1] <= rdata_g;
                                4'd3: kernel[counter-1] <= rdata_b;
                                4'd4: kernel[counter-1] <= rdata_g;
                                4'd5: kernel[counter-1] <= rdata_r;
                                4'd6: kernel[counter-1] <= rdata_g;
                                4'd7: kernel[counter-1] <= rdata_b;
                                4'd8: kernel[counter-1] <= rdata_g;
                                4'd9: kernel[counter-1] <= rdata_b;
                            endcase
                        end
                    endcase
                end
            end

            calculation:
            begin
                cal1 <= kernel[1]+kernel[7];
                cal2 <= kernel[3]+kernel[5];
                cal3 <= kernel[1]+kernel[7]+kernel[3]+kernel[5];
                cal4 <= kernel[0]+kernel[2]+kernel[6]+kernel[8];
                cal5 <= (kernel[1] > kernel[7])? (kernel[1] - kernel[7]):(kernel[7] - kernel[1]);
                cal6 <= (kernel[3] > kernel[5])? (kernel[3] - kernel[5]):(kernel[5] - kernel[3]);
            end
 
            op:
            begin
                cal1 <= 9'd0;
                cal2 <= 9'd0;
                cal3 <= 10'd0;
                cal4 <= 10'd0;
                cal5 <= 8'd0;
                cal2 <= 8'd0;
                if(position[6:0] == 7'b1111110)
                begin
                    row_sel <= ~row_sel;
                    position[13:7] <= x_add;
                    position[6:0] <= 7'd1;
                end
                else
                    position <= position + 14'd1;
                col_sel <= ~col_sel;
                counter <= 4'd0;

                case ({row_sel, col_sel})
                    2'b00://2
                    begin
                        wr_g <= 1'b1;
                        addr_g <= position;
                        if(cal5 == cal6)
                            wdata_g <= (cal3[1])? (cal3[9:2]+8'd1):cal3[9:2];
                        else if(cal5 < cal6)
                            wdata_g <= (cal1[0])? (cal1[8:1]+8'd1):cal1[8:1];
                        else
                            wdata_g <= (cal2[0])? (cal2[8:1]+8'd1):cal2[8:1];
                        wr_r <= 1'b1;
                        addr_r <= position;
                        wdata_r <= (cal4[1])? (cal4[9:2]+8'd1):cal4[9:2];
                    end
                    2'b01://1
                    begin
                        wr_b <= 1'b1;
                        addr_b <= position;
                        wdata_b <= (cal2[0])? (cal2[8:1]+8'd1):cal2[8:1];
                        wr_r <= 1'b1;
                        addr_r <= position;
                        wdata_r <= (cal1[0])? (cal1[8:1]+8'd1):cal1[8:1];
                    end
                    2'b10://4
                    begin
                        wr_b <= 1'b1;
                        addr_b <= position;
                        wdata_b <= (cal1[0])? (cal1[8:1]+8'd1):cal1[8:1];
                        wr_r <= 1'b1;
                        addr_r <= position;
                        wdata_r <= (cal2[0])? (cal2[8:1]+8'd1):cal2[8:1];
                    end
                    2'b11://3
                    begin
                        wr_g <= 1'b1;
                        addr_g <= position;
                        if(cal5 == cal6)
                            wdata_g <= (cal3[1])? (cal3[9:2]+8'd1):cal3[9:2];
                        else if(cal5 < cal6)
                            wdata_g <= (cal1[0])? (cal1[8:1]+8'd1):cal1[8:1];
                        else
                            wdata_g <= (cal2[0])? (cal2[8:1]+8'd1):cal2[8:1];
                        wr_b <= 1'b1;
                        addr_b <= position;
                        wdata_b <= (cal4[1])? (cal4[9:2]+8'd1):cal4[9:2];
                    end
                endcase

            end

            finish:
            begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule
