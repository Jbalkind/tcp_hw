#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "file_testing_lib.h"

#define DEBUG_FILE_IO

void init_with_fds(sock_state *instance_state) {
    instance_state->send_file = fopen("hw_to_sw.txt", "ab+");
    if (instance_state->send_file == NULL) {
         perror("Failed to open hw to sw file");
         exit(1);
    }

    instance_state->recv_file = fopen("sw_to_hw.txt", "ab+");
    if (instance_state->recv_file == NULL) {
        perror("Failed to open sw to hw file");
        exit(1);
    }

    // write the appropriate PCAP headers to both files
    writePCAPHeader(instance_state->send_file);
    writePCAPHeader(instance_state->recv_file);
}

void writePCAPHeader(FILE * f) {
    pcap_file_header hdr;
    hdr.magic_number = 0xa1b2c3d4;
    hdr.version_major = 2;
    hdr.version_minor = 4;
    hdr.thiszone = 0;
    hdr.sigfigs = 0;
    hdr.snaplen = 65535;
    hdr.network = 1; // LINKTYPE_ETHERNET
//    hdr.network = 101; // LINKTYPE_RAW;; There is also LINKTYPE_IPV4/LINKTYPE_IPV6,.

    fwrite(&hdr.magic_number, sizeof(hdr.magic_number), 1, f);
    fwrite(&hdr.version_major, sizeof(hdr.version_major), 1, f);
    fwrite(&hdr.version_minor, sizeof(hdr.version_minor), 1, f);
    fwrite(&hdr.thiszone, sizeof(hdr.thiszone), 1, f);
    fwrite(&hdr.sigfigs, sizeof(hdr.sigfigs), 1, f);
    fwrite(&hdr.snaplen, sizeof(hdr.snaplen), 1, f);
    fwrite(&hdr.network, sizeof(hdr.network), 1, f);
    fflush(f);
}

int read_pcap_record(FILE *pcap_file, unsigned char *buffer) {
    struct pcap_pkthdr pcap_header;
    // read the pcap packet header
    int read_len = fread(&pcap_header, 1, sizeof(struct pcap_pkthdr), pcap_file);

    if (read_len == 0) {
        return 0;
    }

    if (read_len != sizeof(struct pcap_pkthdr)) {
        printf("Error reading pcap packet header\n");
    }

#ifdef DEBUG_FILE_IO
    printf("Packet len is %d\n", pcap_header.len);
#endif

    // read the packet
    read_len = fread(buffer, 1, pcap_header.len, pcap_file);

    if (read_len != pcap_header.len) {
        printf("Error reading pcap packet capture\n");
    }

    return read_len;
}

int write_pcap_record(FILE *pcap_file, unsigned char *buffer, uint32_t buffer_len) {
    uint32_t total_packet_len = buffer_len;
    struct pcap_pkthdr pcap_header;
    struct timeval curr_time;

    gettimeofday(&(curr_time), NULL);

    pcap_header.ts_sec = (uint32_t)(curr_time.tv_sec);
    pcap_header.ts_usec = (uint32_t)(curr_time.tv_usec);
    pcap_header.caplen = total_packet_len;
    pcap_header.len = total_packet_len;

    int write_len = fwrite(&pcap_header, 1, sizeof(struct pcap_pkthdr), pcap_file);
    if (write_len != sizeof(struct pcap_pkthdr)) {
        printf("Error writing pcap packet header\n");
    }

    write_len = fwrite(buffer, 1, total_packet_len, pcap_file);
    if (write_len != total_packet_len ) {
        printf("Error writing pcap packet capture\n");
    }

    fflush(pcap_file);

    return write_len;
}

int get_buffer_from_fd(sock_state *instance_state, unsigned char *buffer) {
    uint32_t packet_len;

    packet_len = read_pcap_record(instance_state->recv_file, buffer);

    return packet_len;
}

int put_buffer_to_fd(sock_state *instance_state, unsigned char *buffer, uint32_t buffer_len) {
    int write_len = write_pcap_record(instance_state->send_file, buffer, buffer_len);

    return write_len;
}
