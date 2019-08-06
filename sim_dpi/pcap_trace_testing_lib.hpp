#ifndef PCAP_TESTING_LIB_HPP
#define PCAP_TESTING_LIB_HPP

#include <vector>
#include <deque>
#include <cstdint>
#include <string>
#include "dpi_testing_lib.hpp"
#include "testing_utils.h"

#define TRACE_FILE_PATH "/homes/sys/katielim/beehive/tcp_apps/echo_app/build/tcp_pull_1_req_test.pcap"

class PcapTestingLib: public DPITestingLib {
    public:
        PcapTestingLib(std::string pcap_filename, struct sock_state &instance_state);

        std::vector<uint8_t> get_buf_fr_io() override;
        int put_buf_on_io(std::vector<uint8_t> pkt_buf) override;

        uint32_t get_packets_to_send();
        uint32_t get_packets_to_recv();

    protected:
        std::deque<std::vector<uint8_t>> send_pkts;
        std::deque<std::vector<uint8_t>> recv_pkts;

        int compare_bufs(std::vector<uint8_t> ref_buf, std::vector<uint8_t> recved_buf);
        void fill_pkt_vectors(FILE *pcap_file, struct sock_state &instance_state);
};

#endif
