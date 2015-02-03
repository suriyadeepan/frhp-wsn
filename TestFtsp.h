#ifndef TEST_FTSP_H
#define TEST_FTSP_H

typedef nx_struct test_ftsp_msg
{
  nx_uint16_t    src_addr;
  nx_uint16_t    counter;
  nx_uint32_t    local_rx_timestamp;
  nx_uint32_t    global_rx_timestamp;
  nx_int32_t     skew_times_1000000;
  nx_uint8_t     is_synced;
  nx_uint16_t    ftsp_root_addr;
  nx_uint8_t     ftsp_seq;
  nx_uint8_t     ftsp_table_entries;
} test_ftsp_msg_t;

enum
{
	AM_TEST_FTSP_MSG = 137
};

#endif
