// MBT 7/7/2016
//
// 1 read-port, 1 write-port ram
//
// reads are synchronous
//
// although we could merge this with normal bsg_mem_1r1w
// and select with a parameter, we do not do this because
// it's typically a very big change to the instantiating code
// to move to/from sync/async, and we want to reflect this.
//

module bsg_mem_1r1w_sync #(parameter width_p=-1
                           , parameter els_p=-1
                           , parameter read_write_same_addr_p=0
                           , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
                           , parameter harden_p=0
                           , parameter disable_collision_warning_p=1
                           )
   (input   clk_i
    , input reset_i

    , input                     w_v_i
    , input [addr_width_lp-1:0] w_addr_i
    , input [width_p-1:0]       w_data_i

    // currently unused
    , input                      r_v_i
    , input [addr_width_lp-1:0]  r_addr_i

    , output logic [width_p-1:0] r_data_o
    );

endmodule