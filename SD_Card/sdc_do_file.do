# sdc_do_file.do
# On the command line type:
# c:\work> vsim -do sdc_do_file.do
# c:\work> being where your work files are located.

# This is the do file for the sdc controller.
#vsim -novopt work.sdc_controller_mod
vsim -novopt work.sdc_controller_mod_tb2

#add wave -position end sim:/sdc_controller_mod/clk
#add wave -position end sim:/sdc_controller_mod/fifo_data
#add wave -position end sim:/sdc_controller_mod/host_tst_cmd_strb
#add wave -position end sim:/sdc_controller_mod/man_init_sdc_strb
#add wave -position end sim:/sdc_controller_mod/rd_reg_indx_puc
#add wave -position end sim:/sdc_controller_mod/rd_reg_output_puc
#add wave -position end sim:/sdc_controller_mod/rdy_for_nxt_pkt
# For host controller
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/command
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/present_state
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/normal_int_status
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/clk
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/transfer_mode
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/strt_adma_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/strt_snd_data_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/new_dat_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/sm_rd_data
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/fifo_rdy_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/end_bit_det_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/D0_in
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/D0_out
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/SDC_CLK
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/wr_reg_index
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/wr_reg_strb_z1
#add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/new_res_pkt_strb
#add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/new_res_pkt_strb_z1
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/end_bit_det_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/end_bit_det_strb_z1
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/end_descr
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/wr_busy
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/wr_busy_z1
# For host bus driver
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_bus_driver_u1/wr_b_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_bus_driver_u1/wr_b_strb_z1
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/wr_b_strb_z2
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/stop_recv_pkt
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/blocks_crc_done_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/str_crc_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/str_crc_strb_z1
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/str_crc_strb_z2
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/str_crc_strb_z3
# hc/snd_dat
add wave -position insertpoint sim:/sdc_controller_mod_tb2/uut/sd_host_controller_u2/sdc_snd_dat_1_bit_u10/sm_rd_data




# For sdc_controller_mod
add wave -position insertpoint sim:/sdc_controller_mod_tb2/strt_fifo_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/rdy_for_nxt_pkt
add wave -position insertpoint sim:/sdc_controller_mod_tb2/reset
add wave -position insertpoint sim:/sdc_controller_mod_tb2/start_data_tf_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/data_in_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/last_set_of_data_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/data
add wave -position insertpoint sim:/sdc_controller_mod_tb2/wr_b_strb
add wave -position insertpoint sim:/sdc_controller_mod_tb2/fifo_data
add wave -position insertpoint sim:/sdc_controller_mod_tb2/sdc_rd_addr
add wave -position insertpoint sim:/sdc_controller_mod_tb2/sdc_wr_addr
add wave -position insertpoint sim:/sdc_controller_mod_tb2/tf_mode
add wave -position insertpoint sim:/sdc_controller_mod_tb2/IO_SDC1_CMD_out
add wave -position insertpoint sim:/sdc_controller_mod_tb2/IO_SDC1_CMD_in
add wave -position insertpoint sim:/sdc_controller_mod_tb2/tf_mode









dd wave -position inwertpoint sim:/sdc_controller_mod_tb2/reset


#add wave -recursive -depth 3 *

# Create the system clock.
#force -freeze sim:/sdc_controller_mod/clk 1 0, 0 {10 ns} -r 20 ns
run 5 ms
