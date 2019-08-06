#include <cstdint>
#include <stdio.h>
#include "pcap_trace_testing_lib.hpp"
#include "pcap_helpers.h"
#include "sim_network_side_queue.hpp"

PcapTestingLib::PcapTestingLib(std::string pcap_filename, 
                                struct sock_state &instance_state) {
    FILE *pcap_file = fopen(pcap_filename.c_str(), "rb");

    if (pcap_file == NULL) {
        perror("Failed to open pcap file");
        exit(1);
    }

    if (consumePCAPHeader(pcap_file) < 0) {
        printf("Error reading PCAP file header\n");
        finish_simulation();
    }

    this->fill_pkt_vectors(pcap_file, instance_state);

    fclose(pcap_file);
}

void PcapTestingLib::fill_pkt_vectors(FILE *pcap_file, struct sock_state &instance_state) {
    uint8_t buffer[2048];
    struct eth_hdr *eth_frame = (struct eth_hdr *)(buffer);
    struct ip_hdr *ip_packet;
    struct tcp_header *tcp_packet;
    uint32_t eth_hdr_size;
    int bytes_read;
    bool send_packet;

    bytes_read = read_pcap_record(pcap_file, buffer);

    while (bytes_read > 0) {
        send_packet = true;
        // check the MAC address to see if we should receive the packet or send it
        for (uint32_t i = 0; i < 6; i++) {
            if (eth_frame->dst_addr[i] != instance_state.source_mac_addr[i]) {
                send_packet = false;
                break;
            }
        }
        std::vector<uint8_t> pkt_buf(buffer, buffer + bytes_read);
        if (send_packet) {
            send_pkts.push_back(pkt_buf);
        }
        else {
            recv_pkts.push_back(pkt_buf);
        }
        bytes_read = read_pcap_record(pcap_file, buffer);
    }
}

std::vector<uint8_t> PcapTestingLib::get_buf_fr_io() {
    if (send_pkts.empty()) {
        std::vector<uint8_t> pkt_buf;
        return pkt_buf;
    }
    else {
        std::vector<uint8_t> pkt_buf = send_pkts.front();
        send_pkts.pop_front();
        return pkt_buf;
    }
}

int PcapTestingLib::put_buf_on_io(std::vector<uint8_t> pkt_buf) {
    if (recv_pkts.empty()) {
        printf("got a packet not in the trace\n");
    }
    else {
        std::vector<uint8_t> ref_pkt = recv_pkts.front();
        recv_pkts.pop_front();

        compare_bufs(ref_pkt, pkt_buf);
        printf("Packets left: %d\n", recv_pkts.size());

        if (recv_pkts.empty()) {
            printf("All packets received\n");
            finish_simulation();
        }
    }

    return pkt_buf.size();
}

int PcapTestingLib::compare_bufs(std::vector<uint8_t> ref_buf,
                                std::vector<uint8_t> recved_buf) {
    if (ref_buf.size() != recved_buf.size()) {
        printf("recved pkt different size\n");
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

uint32_t PcapTestingLib::get_packets_to_send() {
    return send_pkts.size();
}

uint32_t PcapTestingLib::get_packets_to_recv() {
    return recv_pkts.size();
}
