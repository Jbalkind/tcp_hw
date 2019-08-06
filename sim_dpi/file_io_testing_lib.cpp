#include <stdio.h>
#include "file_io_testing_lib.hpp"
#include "pcap_helpers.h"

FileIOTestingLib::FileIOTestingLib(std::string send_file_name, 
                                    std::string recv_file_name) {
    send_file = fopen(send_file_name.c_str(), "ab+");

    if (send_file == NULL) {
        perror("Failed to open hw to sw file");
        exit(1);
    }

    recv_file = fopen(recv_file_name.c_str(), "ab+");
    if (recv_file == NULL) {
        perror("Failed to open sw to hw_file");
        exit(1);
    }

    writePCAPHeader(send_file);
    writePCAPHeader(recv_file);
}

std::vector<uint8_t> FileIOTestingLib::get_buf_fr_io () {
    uint8_t buffer[2048];
    uint32_t packet_len;

    packet_len = read_pcap_record(recv_file, buffer);

    std::vector<uint8_t> pkt_buf(buffer, buffer + packet_len);

    return pkt_buf;
}

int FileIOTestingLib::put_buf_on_io(std::vector<uint8_t> pkt_buf) {
    uint8_t *buffer = pkt_buf.data();
    int write_len = write_pcap_record(send_file, buffer, pkt_buf.size());

    return write_len;
}
