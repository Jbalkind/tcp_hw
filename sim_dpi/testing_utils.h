#ifndef TESTING_UTILS_H
#define TESTING_UTILS_H

#include <vector>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/ether.h>
#include "svdpi.h"
#include "flows.h"
#include "dpi_testing_lib.hpp"

#define REAL_REMOTE
#define RAW 0
#define FILE_IO 1
#define PCAP_TRACE 2
#define BACKEND (PCAP_TRACE) 
#define DEBUG_DPI

#define MAC_INTERFACE_W 256

struct sock_state {
    // only set when testing with raw sockets
    int send_sock;
    int recv_sock;

    struct sockaddr_in source_addr;
    struct sockaddr_in dest_addr;

    uint8_t source_mac_addr[ETHER_ADDR_LEN];
    uint8_t dest_mac_addr[ETHER_ADDR_LEN];
    int has_syn_acked;
    uint32_t init_ack_num;
};


struct rx_header_interface_struct {
    svBitVecVal drive_header_bitvec[6];
    uint32_t drive_src_ip;
    uint32_t drive_dst_ip;
    uint32_t drive_ip_hdr_len;
    uint32_t drive_ip_tot_len;
    bool drive_header_val;
};

struct rx_data_interface_struct {
    uint8_t *buffer;
    uint64_t buffer_len;
    uint64_t buffer_pos;
};

struct tx_data_interface_struct {
    uint64_t buffer_len;
    uint64_t buffer_pos;
    std::vector<uint8_t> buffer;
};


// checksum functions
void add_tcp_checksum(uint8_t *tcp_segment, uint32_t payload_len, 
                      uint32_t source_addr, uint32_t dest_addr);
void add_ip_checksum(struct iphdr *ip_header);
unsigned short csum(unsigned short *ptr, int nbytes);

// internal struct/wire struct conversions
void convert_tcp_header_to_external(struct tcp_header *internal_header, struct tcphdr *wire_header, 
                                    struct sock_state *state);

void convert_ip_header_to_external(struct iphdr *internal_header, struct iphdr *wire_header);

void convert_external_to_tcp_header(struct tcphdr *wire_header, struct tcp_header *internal_header,
                                    struct sock_state *state);

// struct filling
void fill_ip_header(struct sock_state *state, struct iphdr *ip_header, uint32_t payload_len);
void fill_tcp_header(struct sock_state *state, struct tcphdr *tcp_header, uint32_t seq_num, 
                    uint32_t ack_num, uint8_t syn, uint8_t ack, struct sockaddr_in * dest_addr);

// Verilog/C struct conversions
void bitvec_to_tcp_header(svBitVecVal *bitvec, struct tcp_header *header_struct);
void bitvec_to_ip_header(svBitVecVal *bitvec, struct iphdr *header_struct);
void tcp_header_to_bitvec(struct tcp_header *header_struct, svBitVecVal *bitvec);
void data_swizzle_64_bitvec_to_c_buf(svBitVecVal *data_input, uint8_t *dest_buf);
void data_swizzle_64_c_buf_to_dpi_longint(uint8_t *data_input, uint64_t *dest_buf);

// Control CPU emulation
//void send_syn_ack(struct sock_state *state, struct sockaddr_in *recv_packet_source_address,
//                  struct tcphdr *recv_tcp_header);
void handle_arp(DPITestingLib *backend, struct sock_state *state, 
                struct ether_arp *arp_req);

// Printing
void print_tcp_header(struct tcp_header * print_header);
void print_ip_header(struct iphdr * print_header);
void print_wire_header(uint8_t *packet_buffer);
#endif
