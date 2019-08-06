#ifndef TCP_PCAP_TESTING_LIB_HPP
#define TCP_PCAP_TESTING_LIB_HPP

#include <vector>
#include <queue>
#include <deque>
#include <cstdint>
#include <string>
#include <unordered_map>
#include "dpi_testing_lib.hpp"
#include "testing_utils.h"
#include "flows.h"

class TCPMimic {
    public:
        TCPMimic(bool handshake_done) :
            handshake_done(handshake_done) {}

        // increment the sequence number by the buffer length and return the OLD value
        // of the sequence number
        uint32_t update_my_ack(uint32_t buf_len);
        // increment the ack number by the buffer length and return the OLD value of the
        // ack number
        uint32_t update_their_ack(uint32_t buf_len);

        void set_my_seq(uint32_t seq_num);
        void set_their_seq(uint32_t seq_num);
        void set_my_ack(uint32_t ack_num);
        void set_their_ack(uint32_t ack_num);

        bool check_my_ack(uint32_t check_ack_num);

        void set_handshake_done(bool done);
        bool get_handshake_done();

        bool pkts_recved_empty();
        std::vector<uint8_t> get_pkts_recved_front();
        void put_pkts_recved_back(std::vector<uint8_t> &pkt_buf);
        
        bool pkts_to_send_empty();
        std::vector<uint8_t> get_pkts_to_send_front();
        void put_pkts_to_send_back(std::vector<uint8_t> &pkt_buf);
        
        bool pkts_to_recv_empty();
        std::vector<uint8_t> get_pkts_to_recv_front();
        void put_pkts_to_recv_back(std::vector<uint8_t> &pkt_buf);
        uint64_t pkts_to_recv_size();

    private:
        bool handshake_done;
        uint32_t my_seq;
        uint32_t my_expected_ack;
        uint32_t their_seq;
        uint32_t their_expected_ack;

        std::queue<std::vector<uint8_t>> pkts_recved_buf;
        std::queue<std::vector<uint8_t>> pkts_to_recv;
        std::queue<std::vector<uint8_t>> pkts_to_send;

};

class TCPPcapTestingLib: public DPITestingLib {
    public:
        TCPPcapTestingLib(std::string pcap_filename, struct sock_state &instance_state);
        
        std::vector<uint8_t> get_buf_fr_io() override;
        int put_buf_on_io(std::vector<uint8_t> pkt_buf) override;

    protected:
        int compare_bufs(std::vector<uint8_t> ref_buf, std::vector<uint8_t> recved_buf);
        void fill_pkt_vectors(FILE *pcap_file, struct sock_state &instance_state);

    private:
        FILE *pcap_file;
        std::unordered_map<TCPFlowTuple, TCPMimic, TCPFlowTupleHash> tcp_flows;
        struct sock_state *instance_state;
        
        void buf_process_helper(std::vector<uint8_t> &pkt_buf,
                                TCPMimic &tcp_context);

        void recv_buf_helper(std::vector<uint8_t> &pkt_buf,
                            TCPMimic &tcp_context);
};

#endif
