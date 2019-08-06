#include <cstdint>
#include <stdio.h>
#include "flows.h"
#include "tcp_pcap_trace_testing_lib.hpp"
#include "pcap_helpers.h"
#include "sim_network_side_queue.hpp"

#define TCP_TRACE_DEBUG 

TCPPcapTestingLib::TCPPcapTestingLib(std::string pcap_filename, 
                                    struct sock_state &instance_state) {
    this->pcap_file = fopen(pcap_filename.c_str(), "rb");
    if (pcap_file == NULL) {
        perror("Failed to open pcap file");
        exit(1);
    }

    if (consumePCAPHeader(pcap_file) < 0) {
        printf("Error reading PCAP file header\n");
        finish_simulation();
    }

    this->instance_state = &instance_state;
}

void TCPPcapTestingLib::fill_pkt_vectors(FILE *pcap_filename, 
                                         struct sock_state &instance_state) {
    return;
}

std::vector<uint8_t> TCPPcapTestingLib::get_buf_fr_io() {
    uint8_t buffer[2048];
    struct eth_hdr *eth_frame = (struct eth_hdr *)(buffer);
    struct ip_hdr *ip_packet = (struct ip_hdr *)(buffer + sizeof(struct eth_hdr));
    uint8_t ip_hdr_ihl = (ip_packet->ver_ihl) & (uint8_t)0xf;
    struct tcp_header *tcp_packet = (struct tcp_header *)((uint8_t *)ip_packet + 
            (ip_hdr_ihl << 2));
    uint32_t eth_hdr_size;
    int bytes_read;
    bool send_packet = true;
    bytes_read = read_pcap_record(pcap_file, buffer);

    if (bytes_read > 0) {
        std::vector<uint8_t> pkt_buf(buffer, buffer + bytes_read);
        // check the MAC address to see if we should receive the packet or send it
        for (uint32_t i = 0; i < 6; i++) {
            if (eth_frame->dst_addr[i] != (instance_state->source_mac_addr)[i]) {
                send_packet = false;
                break;
            }
        }
#ifdef TCP_TRACE_DEBUG
        if (send_packet) {
            printf("Sending packet\n");
        }
        else {
            printf("Receiving packet\n");
        }
#endif

        // find the right TCP lookup struct
        struct TCPFlowTuple lookup_tuple;
        if (send_packet) {
            lookup_tuple.my_ip = ip_packet->src_addr;
            lookup_tuple.their_ip = ip_packet->dst_addr;
            lookup_tuple.my_port = tcp_packet->src_port;
            lookup_tuple.their_port = tcp_packet->dst_port;
        }
        else {
            lookup_tuple.their_ip = ip_packet->src_addr;
            lookup_tuple.my_ip = ip_packet->dst_addr;
            lookup_tuple.their_port = tcp_packet->src_port;
            lookup_tuple.my_port = tcp_packet->dst_port;
        }

        // see if we have an entry for it?
        auto tcp_flows_it = tcp_flows.find(lookup_tuple);
        // okay there is an existing entry
        if (tcp_flows_it != tcp_flows.end()) {
            // get a reference to the context
            TCPMimic &flow_context = tcp_flows_it->second;
            // are we supposed to send this packet or receive it?
            // if we're supposed to send it, check if we've completed the handshake and
            // send either this packet or one that's buffered
            if (send_packet) {
                if (flow_context.get_handshake_done()) {
                    if (flow_context.pkts_to_send_empty()) {
                        // do some packet parsing to update our state
                        buf_process_helper(pkt_buf, flow_context);
                        return pkt_buf;
                    }
                    else {
                        flow_context.put_pkts_to_send_back(pkt_buf);

                        std::vector<uint8_t> buf_to_return = flow_context.get_pkts_to_send_front();
            
                        // do some packet parsing to update our state
                        buf_process_helper(buf_to_return, flow_context);
                        return buf_to_return;
                    }
                }
                // we haven't received the SYN-ACK, so we just have to wait
                else {
                    flow_context.put_pkts_to_send_back(pkt_buf);
                    std::vector<uint8_t> pkt_buf;
                    return pkt_buf;
                }
            }
            // if we're actually supposed to receive it, queue it to check later
            else {
                flow_context.put_pkts_to_recv_back(pkt_buf);
                std::vector<uint8_t> empty_buf;
                return empty_buf;
            }
        }
        // okay there's no existing entry, so create one
        else {
            TCPMimic new_context(false);
            if (send_packet) {
                // just send the packet since this has to be the SYN
                buf_process_helper(pkt_buf, new_context);

                tcp_flows.insert(std::make_pair(lookup_tuple, new_context));
                return pkt_buf;
            }
            else {
                new_context.put_pkts_to_recv_back(pkt_buf);
                tcp_flows.insert(std::make_pair(lookup_tuple, new_context));
                std::vector<uint8_t>empty_buf;
                return empty_buf;
            }
        }

    }
    // otherwise, we have no more data from the file, but we may have some
    // packets that are waiting to be sent, so iterate over the map
    else {
        for (auto &it : tcp_flows) {
            TCPMimic &flow_context = it.second;
            if (!flow_context.pkts_to_send_empty()) {
                std::vector<uint8_t> pkt_buf = flow_context.get_pkts_to_send_front();
                // we know we have to send this, so we don't need to check anything
                buf_process_helper(pkt_buf, flow_context);

                return pkt_buf;
            }

        }
        // alright if we've reached this point, there are no flows with packets
        // outstanding, so just return an empty buffer
        std::vector<uint8_t> empty_buf;
        return empty_buf;
    }

}

int TCPPcapTestingLib::put_buf_on_io(std::vector<uint8_t> pkt_buf) {
    uint8_t *buffer = pkt_buf.data();
    struct eth_hdr *eth_frame = (struct eth_hdr *)(buffer);
    struct ip_hdr *ip_packet = (struct ip_hdr *)(buffer + sizeof(struct eth_hdr));
    uint8_t ip_hdr_ihl = (ip_packet->ver_ihl) & (uint8_t)0xf;
    struct tcp_header *tcp_packet = (struct tcp_header *)((uint8_t *)ip_packet + 
            (ip_hdr_ihl << 2));
    bool send_packet = true;
        
    // check the MAC address to see if we should receive the packet or send it
    for (uint32_t i = 0; i < 6; i++) {
        if (eth_frame->dst_addr[i] != instance_state->source_mac_addr[i]) {
            send_packet = false;
            break;
        }
    }

    // find the right TCP lookup struct
    TCPFlowTuple lookup_tuple;
    if (send_packet) {
        lookup_tuple.my_ip = ip_packet->src_addr;
        lookup_tuple.their_ip = ip_packet->dst_addr;
        lookup_tuple.my_port = tcp_packet->src_port;
        lookup_tuple.their_port = tcp_packet->dst_port;
    }
    else {
        lookup_tuple.their_ip = ip_packet->src_addr;
        lookup_tuple.my_ip = ip_packet->dst_addr;
        lookup_tuple.their_port = tcp_packet->src_port;
        lookup_tuple.my_port = tcp_packet->dst_port;
    }
        
    // see if we have an entry for it?
    auto tcp_flows_it = tcp_flows.find(lookup_tuple);
    // okay there is an existing entry
    if (tcp_flows_it != tcp_flows.end()) {
        printf("Receive trace found an entry\n");
        // get a reference to the context
        TCPMimic &flow_context = tcp_flows_it->second;
        printf("%lu packets to receive\n", flow_context.pkts_to_recv_size());
        // check to see if we can compare against any packets
        // if not, we'll need to wait for a packet to compare this against
        while ((!flow_context.pkts_to_recv_empty()) && 
                (!flow_context.pkts_recved_empty())) {
            // just try to dequeue everything possible
            std::vector<uint8_t> ref_pkt = flow_context.get_pkts_to_recv_front(); 
            std::vector<uint8_t> test_pkt = flow_context.get_pkts_recved_front();

            compare_bufs(ref_pkt, test_pkt);
        }
        // okay, one or the other is empty. if we have nothing left to compare
        // against, we need to enqueue this packet from the hardware
        if (flow_context.pkts_to_recv_empty()) {
            printf("No packets to compare to\n");
            flow_context.put_pkts_recved_back(pkt_buf);
        }
        else {
            std::vector<uint8_t> ref_pkt = flow_context.get_pkts_to_recv_front();
            compare_bufs(ref_pkt, pkt_buf);
        }
    }
    return pkt_buf.size();
}

void TCPPcapTestingLib::recv_buf_helper(std::vector<uint8_t> &pkt_buf,
                                        TCPMimic &tcp_context) {
    uint8_t *buffer = pkt_buf.data();
    struct eth_hdr *eth_frame = (struct eth_hdr *)(buffer);
    struct ip_hdr *ip_packet = (struct ip_hdr *)(buffer + sizeof(struct eth_hdr));
    uint8_t ip_hdr_ihl = (ip_packet->ver_ihl) & (uint8_t)0xf;
    struct tcp_header *tcp_packet = (struct tcp_header *)((uint8_t *)ip_packet + 
            (ip_hdr_ihl << 2));

    // check for a SYN-ACK
    if (tcp_packet->flags == (uint8_t)(TCP_ACK | TCP_SYN)) {
        // check if the ACK number is okay
        if (!tcp_context.check_my_ack(tcp_packet->ack_num)) {
            printf("Warning: SYN-ACK ack number not ok\n");
        }
        tcp_context.set_their_seq(tcp_packet->seq_num);
        tcp_context.set_their_ack(tcp_packet->seq_num + 1);
        tcp_context.set_handshake_done(true);
    }
    else if (tcp_packet->flags == (uint8_t)(TCP_ACK)) {
        // find the payload size
        uint32_t ip_hdr_len = (ip_packet->ver_ihl & (uint8_t)(0xf)) << 2;
        uint32_t tcp_hdr_len = ((tcp_packet->_hdrlen_rsvd_nonce) >> 4) << 2;
        uint16_t payload_len = (ip_packet->total_length) - ip_hdr_len - tcp_hdr_len;
        if (!tcp_context.check_my_ack(tcp_packet->ack_num)) {
            printf("Warning: ACK number not ok\n");
        }

        tcp_context.set_their_seq(tcp_packet->seq_num);
        tcp_context.update_their_ack(payload_len);
    }
    else {
        printf("Warning: bad TCP flags\n");
    }
}

int TCPPcapTestingLib::compare_bufs(std::vector<uint8_t> ref_buf,
                                std::vector<uint8_t> recved_buf) {
    printf("Comparing bufs\n");
    if (ref_buf.size() != recved_buf.size()) {
        printf("recved pkt different size\n");
        printf("ref size: %lu, recved size: %lu\n", ref_buf.size(), recved_buf.size());
        finish_simulation();
    }
    else {
        for (uint32_t i = 0; i < ref_buf.size(); i++) {
            if (ref_buf[i] != recved_buf[i]) {
                printf("recved pkt different at byte %d. Expected %hhx, Got %hhx\n",
                        i, ref_buf[i], recved_buf[i]);
            }
        }
    }
    return 0;
}

// TCP Mimic state stuff

void TCPPcapTestingLib::buf_process_helper(std::vector<uint8_t> &pkt_buf, 
                                           TCPMimic &tcp_context) {
    // do some packet parsing to update our state
    uint8_t *sending_buf = pkt_buf.data();
    eth_hdr *eth = (eth_hdr *)(sending_buf);
    ip_hdr *ip = (ip_hdr *)(sending_buf + sizeof(eth_hdr));
    uint32_t ip_hdr_len = (ip->ver_ihl & (uint8_t)(0xf)) << 2;
    tcp_header *tcp = (tcp_header *)((uint8_t *)ip + ip_hdr_len);

    // find the payload size
    uint32_t tcp_hdr_len = ((tcp->_hdrlen_rsvd_nonce) >> 4) << 2;
    uint16_t payload_len = (ip->total_length) - ip_hdr_len - tcp_hdr_len;

    tcp_context.set_my_seq(tcp->seq_num);
    // is this a SYN?
    if (tcp->flags == (uint8_t)(TCP_SYN)) {
        tcp_context.set_my_ack(tcp->seq_num + 1);
    }
    else {
        tcp_context.update_my_ack(payload_len);
    }
}

uint32_t TCPMimic::update_my_ack(uint32_t buf_len) {
    uint32_t return_val = this->my_expected_ack;
    this->my_expected_ack = this->my_expected_ack + buf_len;
    return return_val;
}

uint32_t TCPMimic::update_their_ack(uint32_t buf_len) {
    uint32_t return_val = this->their_expected_ack;
    this->their_expected_ack = this->their_expected_ack + buf_len;
    return return_val;
}

void TCPMimic::set_my_seq(uint32_t seq_num) {
    this->my_seq = seq_num;
}

void TCPMimic::set_their_seq(uint32_t seq_num) {
    this->their_seq = seq_num;
}

void TCPMimic::set_my_ack(uint32_t ack_num) {
    this->my_expected_ack = ack_num;
}

void TCPMimic::set_their_ack(uint32_t ack_num) {
    this->their_expected_ack = ack_num;
}

void TCPMimic::set_handshake_done(bool done) {
    this->handshake_done = done;
}

bool TCPMimic::get_handshake_done() {
    return this->handshake_done;
}

bool TCPMimic::pkts_recved_empty() {
    return this->pkts_recved_buf.empty();
}

std::vector<uint8_t> TCPMimic::get_pkts_recved_front() {
    std::vector<uint8_t> &buf_front = this->pkts_recved_buf.front();
    std::vector<uint8_t> buf_to_return(buf_front);
    this->pkts_recved_buf.pop();

    return buf_to_return;
}

void TCPMimic::put_pkts_recved_back(std::vector<uint8_t> &pkt_buf) {
    this->pkts_recved_buf.push(pkt_buf);
}

bool TCPMimic::pkts_to_recv_empty() {
    return this->pkts_to_recv.empty();
}

std::vector<uint8_t> TCPMimic::get_pkts_to_recv_front() {
    std::vector<uint8_t> &buf_front = this->pkts_to_recv.front();
    std::vector<uint8_t> buf_to_return(buf_front);
    this->pkts_to_recv.pop();

    return buf_to_return;
}

void TCPMimic::put_pkts_to_recv_back(std::vector<uint8_t> &pkt_buf) {
    this->pkts_to_recv.push(pkt_buf);
}

uint64_t TCPMimic::pkts_to_recv_size() {
    return this->pkts_to_recv.size();
}

bool TCPMimic::pkts_to_send_empty() {
    return this->pkts_to_send.empty();
}

std::vector<uint8_t> TCPMimic::get_pkts_to_send_front() {
    std::vector<uint8_t> &buf_front = this->pkts_to_send.front();
    std::vector<uint8_t> buf_to_return(buf_front);
    this->pkts_to_send.pop();

    return buf_to_return;
}

void TCPMimic::put_pkts_to_send_back(std::vector<uint8_t> &pkt_buf) {
    this->pkts_to_send.push(pkt_buf);
}
