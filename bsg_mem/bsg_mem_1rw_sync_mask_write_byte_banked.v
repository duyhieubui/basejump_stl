/**
 *  bsg_mem_1rw_sync_mask_write_byte_banked.v
 *
 *  This module has the same interface/functionality as
 *  bsg_mem_1rw_sync_mask_write_byte.
 *
 *  This module can be used for breaking a big SRAM block into
 *  smaller blocks. This might be useful, if the SRAM generator does not
 *  support sizes of SRAM that are too wide or too deep.
 *  It is also useful for power and delay perspective, since only one depth
 *  bank is activated while reading or writing.
 *
 *
 *  - width_p : width of the total memory
 *  - els_p : depth of the total memory
 *
 *  - num_width_bank_p : Number of banks for the memory's width. width_p has
 *    to be a multiple of this number.
 *  - num_depth_bank_p : Number of banks for the memory's depth. els_p has to
 *    be a multiple of this number.
 *
 *  - depth_bank_start_idx_p : this specifies the starting index of addr_i
 *    that is used for selecting the depth bank. The rest of the bits in addr_i
 *    are used for indexing into smaller SRAM banks.
 *
 *    To use LSB bits, set this to 0.
 *    To use MSB bits, set this to $clog2(els_p) - $clog2(num_depth_bank_p).
 *
 *    This parameter has no meaning if num_depth_bank_p is 1.
 *
 */


module bsg_mem_1rw_sync_mask_write_byte_banked
  #(parameter data_width_p="inv"
    , parameter els_p="inv"
    , parameter latch_last_read_p=0

    , parameter write_mask_width_lp=(data_width_p>>3)

    // bank parameters
    , parameter num_width_bank_p=1
    , parameter num_depth_bank_p=1
    , parameter depth_bank_start_idx_p=0

    , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
    , parameter bank_depth_lp=(els_p/num_depth_bank_p)
    , parameter bank_addr_width_lp=`BSG_SAFE_CLOG2(bank_depth_lp)
    , parameter depth_bank_idx_width_lp=`BSG_SAFE_CLOG2(num_depth_bank_p)
    , parameter bank_width_lp=(data_width_p/num_width_bank_p)
    , parameter bank_mask_width_lp=(bank_width_lp>>3)
  )
  (
    input clk_i
    , input reset_i
    
    , input v_i
    , input w_i

    , input [addr_width_lp-1:0] addr_i
    , input [data_width_p-1:0] data_i
    , input [write_mask_width_lp-1:0] write_mask_i
    , output [data_width_p-1:0] data_o
  );


  if (num_depth_bank_p==1) begin: db1

    for (genvar i = 0; i < num_width_bank_p; i++) begin: wb
      bsg_mem_1rw_sync_mask_write_byte #(
        .data_width_p(bank_width_lp)
        ,.els_p(bank_depth_lp)
        ,.latch_last_read_p(latch_last_read_p)
      ) bank (
        .clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.v_i(v_i)
        ,.w_i(w_i)
        ,.addr_i(addr_i)
        ,.data_i(data_i[bank_width_lp*i+:bank_width_lp])
        ,.write_mask_i(write_mask_i[bank_mask_width_lp*i+:bank_mask_width_lp])
        ,.data_o(data_o[bank_width_lp*i+:bank_width_lp])
      );
    end

  end
  else begin: dbn

    logic [depth_bank_idx_width_lp-1:0] depth_bank_idx_li;
    logic [num_depth_bank_p-1:0] bank_v_li;
    logic [bank_addr_width_lp-1:0] bank_addr_li;
    logic [num_depth_bank_p-1:0][data_width_p-1:0] bank_data_lo;
   
    assign depth_bank_idx_li = addr_i[depth_bank_start_idx_p+:depth_bank_idx_width_lp];
    
    if (depth_bank_start_idx_p == 0) begin // LSB

      assign bank_addr_li = addr_i[depth_bank_idx_width_lp+:bank_addr_width_lp];

    end
    else if (depth_bank_start_idx_p == (addr_width_lp-depth_bank_idx_width_lp)) begin // MSB

      assign bank_addr_li = addr_i[0+:bank_addr_width_lp];

    end
    else begin // in the middle

      assign bank_addr_li =
        {addr_i[addr_width_lp-1:depth_bank_start_idx_p+depth_bank_idx_width_lp],
         addr_i[depth_bank_start_idx_p-1:0]};

    end

    bsg_decode_with_v #(
      .num_out_p(num_depth_bank_p)
    ) demux_v (
      .i(depth_bank_idx_li)
      ,.v_i(v_i)
      ,.o(bank_v_li)
    );
    
    for (genvar i = 0; i < num_width_bank_p; i++) begin: wb
      for (genvar j = 0; j < num_depth_bank_p; j++) begin: db

        bsg_mem_1rw_sync_mask_write_byte #(
          .data_width_p(bank_width_lp)
          ,.els_p(bank_depth_lp)
          ,.latch_last_read_p(latch_last_read_p)
        ) bank (
          .clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.v_i(bank_v_li[j])
          ,.w_i(w_i)
          ,.addr_i(bank_addr_li)
          ,.data_i(data_i[i*bank_width_lp+:bank_width_lp])
          ,.write_mask_i(write_mask_i[i*bank_mask_width_lp+:bank_mask_width_lp])
          ,.data_o(bank_data_lo[j][i*bank_width_lp+:bank_width_lp])
        );

      end
    end

    logic [depth_bank_idx_width_lp-1:0] depth_bank_idx_r;

    bsg_dff_en #(
      .width_p(depth_bank_idx_width_lp)
    ) depth_bank_idx_dff (
      .clk_i(clk_i)
      ,.en_i(v_i & ~w_i)
      ,.data_i(depth_bank_idx_li)
      ,.data_o(depth_bank_idx_r)
    );


    bsg_mux #(
      .els_p(num_depth_bank_p)
      ,.width_p(data_width_p)
    ) data_out_mux (
      .data_i(bank_data_lo)
      ,.sel_i(depth_bank_idx_r)
      ,.data_o(data_o)
    );

  end


  // synopsys translate_off

  initial begin

    assert (data_width_p % 8 == 0)
      else $error("data_width_p is not multiple of 8. %m");

    assert(els_p % num_depth_bank_p == 0)
      else $error("[BSG_ERROR] num_depth_bank_p does not divide even with els_p. %m");

    assert(data_width_p % num_width_bank_p == 0)
      else $error("[BSG_ERROR] num_width_bank_p does not divide even with width_p. %m");

    // this assertion will not even fire,
    // because the compilation will fail before simulation begins.
    assert((depth_bank_start_idx_p>=0) & ((depth_bank_start_idx_p+depth_bank_idx_width_lp)<=addr_width_lp))
      else $error("[BSG_ERROR] depth_bank_start_idx_p out of range. %m");

  end
  
  // synopsys translate_on


endmodule
