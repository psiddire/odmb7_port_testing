
# delete_hw_probe [get_hw_probes txdata_ddu_int ]
# delete_hw_probe [get_hw_probes txd_valid_ddu_int ]
# delete_hw_probe [get_hw_probes txd_ddu_init_ctr ]
# delete_hw_probe [get_hw_probes txdata_spy_int ]
# delete_hw_probe [get_hw_probes rxdata_ddu_ch ]
# delete_hw_probe [get_hw_probes rxd_valid_ddu ]
# delete_hw_probe [get_hw_probes rxready_ ]
# delete_hw_probe [get_hw_probes prbs_match_ddu ]
# delete_hw_probe [get_hw_probes prbs_anyerr_ddu ]
# delete_hw_probe [get_hw_probes txdata_spy ]
# delete_hw_probe [get_hw_probes txd_valid_spy ]
# delete_hw_probe [get_hw_probes rxdata_spy ]
# delete_hw_probe [get_hw_probes rxd_valid_spy ]
# delete_hw_probe [get_hw_probes rxready_spy ]
# delete_hw_probe [get_hw_probes prbs_anyerr_spy ]

# delete_hw_probe [get_hw_probes gtwiz_userdata_rx_int]
# delete_hw_probe [get_hw_probes ch0_codevalid]
# delete_hw_probe [get_hw_probes bad_rx_int]
# delete_hw_probe [get_hw_probes rxd_valid_int]
# delete_hw_probe [get_hw_probes ch0_rxcharisk]
# delete_hw_probe [get_hw_probes ch0_rxdisperr]
# delete_hw_probe [get_hw_probes ch0_rxchariscomma]
# delete_hw_probe [get_hw_probes ch0_rxnotintable]

# DDU RX
# create_hw_probe -map probe0[15:0]     rxdata_ddu_ch_1[15:0] [get_hw_ilas hw_ila_1]
# create_hw_probe -map probe0[31:16]    rxdata_ddu_ch_3[15:0] [get_hw_ilas hw_ila_1]
# create_hw_probe -map probe0[35:32]    rxd_valid_ddu[3:0] [get_hw_ilas hw_ila_1]
# create_hw_probe -map probe0[36]       rxready_ddu [get_hw_ilas hw_ila_1]
# create_hw_probe -map probe0[52:37]    prbs_anyerr_ddu_1[15:0] [get_hw_ilas hw_ila_1]
# create_hw_probe -map probe0[68:53]    prbs_anyerr_ddu_3[15:0] [get_hw_ilas hw_ila_1]

# # DDU TX
# create_hw_probe -map probe0[15:0]     txdata_ddu_prbs_int[15:0] [get_hw_ilas hw_ila_3]
# create_hw_probe -map probe0[31:16]    txdata_ddu_cntr_int[15:0] [get_hw_ilas hw_ila_3]
# create_hw_probe -map probe0[32]       txd_valid_ddu_int [get_hw_ilas hw_ila_3]
# create_hw_probe -map probe0[48:33]    txd_ddu_init_ctr[15:0] [get_hw_ilas hw_ila_3]
# create_hw_probe -map probe0[64:49]    txdata_spy_int[15:0] [get_hw_ilas hw_ila_3]

# # SPY RX
# create_hw_probe -map {probe0[15:0]}   rxdata_spy[15:0] [get_hw_ilas hw_ila_3]
# create_hw_probe -map {probe0[16]}     rxd_valid_spy [get_hw_ilas hw_ila_3]
# create_hw_probe -map {probe0[17]}     rxready_spy [get_hw_ilas hw_ila_3]
# create_hw_probe -map {probe0[34:19]}  prbs_anyerr_spy[15:0] [get_hw_ilas hw_ila_3]

# # SPY TX
# create_hw_probe -map {probe0[15:0]}   txdata_spy[15:0] [get_hw_ilas hw_ila_5]
# create_hw_probe -map {probe0[16]}     txd_valid_spy [get_hw_ilas hw_ila_5]

# MGT_SPY
create_hw_probe -map {probe0[15:0]}   gtwiz_userdata_rx_spy[15:0]  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[19:16]}  ch0_codevalid[3:0]  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[20]}     bad_rx_spy  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[21]}     rxd_valid_int  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[27:24]}  ch0_rxcharisk[3:0]  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[31:28]}  ch0_rxdisperr[3:0]  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[35:32]}  ch0_rxchariscomma[3:0]  [get_hw_ilas hw_ila_2]
create_hw_probe -map {probe0[39:36]}  ch0_rxnotintable[3:0]  [get_hw_ilas hw_ila_2]

# MGT_DDU
create_hw_probe -map {probe0[63:0]}  gtwiz_userdata_rx_int[63:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[15:0]}  rxdata_ddu_ch1[15:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[31:16]} rxdata_ddu_ch2[15:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[47:32]} rxdata_ddu_ch3[15:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[63:48]} rxdata_ddu_ch4[15:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[65:64]} codevalid_ch1[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[69:68]} codevalid_ch3[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[73:70]} rxbyteisaligned_int[3:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[77:74]} rxbyterealign_int[3:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[79:78]} rxnotintable_ch1[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[81:80]} rxnotintable_ch3[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[83:82]} rxdisperr_ch1[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[85:84]} rxdisperr_ch3[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[87:86]} rxcharisk_ch1[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[89:88]} rxcharisk_ch3[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[91:90]} rxchariscomma_ch1[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[93:92]} rxchariscomma_ch3[1:0] [get_hw_ilas hw_ila_1]
create_hw_probe -map {probe0[97:94]} bad_rx_int[3:0] [get_hw_ilas hw_ila_1]


# Control_FSM


# delete_hw_probe [get_hw_probes rxdata_spy ]
# delete_hw_probe [get_hw_probes rxd_valid_spy ]
# delete_hw_probe [get_hw_probes rxready_spy ]
# delete_hw_probe [get_hw_probes prbs_anyerr_spy ]
# delete_hw_probe [get_hw_probes txdata_spy ]
# delete_hw_probe [get_hw_probes txd_valid_spy ]

