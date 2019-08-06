// C++ includes
#include <string>

// C includes
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netinet/ether.h> 
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <errno.h>

#include "flows.h"
#include "testing_utils.h"
#include "dpi_testing_lib.hpp"
#include "file_io_testing_lib.hpp"
#include "pcap_trace_testing_lib.hpp"
#include "tcp_pcap_trace_testing_lib.hpp"
#include "sim_network_side_queue.hpp"
#include "svdpi.h"

/*******************************************************************
 * State things
 ******************************************************************/
struct sock_state instance_state;
struct rx_data_interface_struct rx_data_if;
struct tx_data_interface_struct tx_data_if;

DPITestingLib *sim_backend;
/*******************************************************************
 * Function declarations
 ******************************************************************/
// Verilog function imports
extern "C" void drive_rx_if(bool val, svBitVecVal *data, bool last, int padbytes);
extern "C" void finish_from_c(void);

static int recv_from_socket(void);
static void send_on_socket(void);

extern "C" void get_data(void);
extern "C" void put_data(svBitVecVal *data, bool last, int padbytes);
extern "C" void init_network_side_state();


/*******************************************************************
 * RX Path
 ******************************************************************/
extern "C" void get_data(void) {
    svBitVecVal buffer_data[MAC_INTERFACE_W >> 5];
    uint8_t *buffer_copy_ptr = (uint8_t *)buffer_data;
    int i;
    if (rx_data_if.buffer_pos >= rx_data_if.buffer_len) {
        int status = recv_from_socket(); 

        // if for some reason, we didn't get any data from the interface
        if (status == 0) {
            for (int j = 0; j < MAC_INTERFACE_W >> 3; j++) {
                buffer_copy_ptr[j] = 0;
            }
            drive_rx_if(false, buffer_data, false, 0);
            return;
        }
    }

    // copy data into the svBitVecVal, ending when we run out of buffer or we run out of
    // space in the svBitVecVal, whichever comes first
    for (i = (MAC_INTERFACE_W >> 3) - 1; rx_data_if.buffer_pos < rx_data_if.buffer_len 
            && i >= 0; i--, rx_data_if.buffer_pos++) {
        buffer_copy_ptr[i] = rx_data_if.buffer[rx_data_if.buffer_pos];
    }

    // Save padbytes and last
    int padbytes = i + 1;
    bool last = (rx_data_if.buffer_pos == rx_data_if.buffer_len);

    // Pad out the svBitVecVal with zeros if necessary, start from where we left off, so don't
    // reinitialize i
    for (; i >= 0; i--) {
        buffer_copy_ptr[i] = 0;
    }

    printf("Buffer is: ");
    for (int index = 0; index < MAC_INTERFACE_W >> 3; index++) {
        printf("%hhx ", buffer_copy_ptr[index]);
    }
    printf("\n");


    drive_rx_if(true, buffer_data, last, padbytes);
    if (rx_data_if.buffer_pos >= rx_data_if.buffer_len) {
        free(rx_data_if.buffer);
    }
}

static int recv_from_socket(void) {
    uint8_t *buffer;
    struct ether_header *eth_frame;
    struct iphdr *ip_packet;
    struct tcphdr *tcp_packet;
    // Structs that contain source and dest IP addresses in the packets
    struct sockaddr_in recv_packet_source_address, recv_packet_dest_address;
    struct sockaddr_in send_packet_source_address, send_packet_dest_address;
    memset(&recv_packet_source_address, 0, sizeof(struct sockaddr_in));
    memset(&recv_packet_dest_address, 0, sizeof(struct sockaddr_in));

    int buf_len;

    std::vector<uint8_t> pkt_buf = sim_backend->get_buf_fr_io();
    buffer = pkt_buf.data();
    buf_len = pkt_buf.size();

    if (buf_len == 0) {
        return 0;
    }

    eth_frame = (struct ether_header *)(buffer);
    if (ntohs(eth_frame->ether_type) == ETHERTYPE_ARP) {
        printf("Got ARP\n");
        struct ether_arp *arp_req = (struct ether_arp *)(buffer + sizeof(ether_header));
        handle_arp(sim_backend, &instance_state, arp_req);
        return 0;
    }
    else if (ntohs(eth_frame->ether_type) != ETHERTYPE_IP) {
        return 0;
    }

    ip_packet = (struct iphdr *)(buffer + sizeof(ether_header));

//    // Only accept TCP
//    if (ip_packet->protocol != IPPROTO_TCP) {
//        return 0;
//    }
//
//    tcp_packet = (struct tcphdr *)(buffer + sizeof(ether_header) + (ip_packet->ihl << 2));
//    recv_packet_source_address.sin_addr.s_addr = ip_packet->saddr;
//    recv_packet_source_address.sin_port = ntohs(tcp_packet->source);
//    recv_packet_dest_address.sin_addr.s_addr = ip_packet->daddr;
//    recv_packet_dest_address.sin_port = ntohs(tcp_packet->dest);
//
//#ifdef DEBUG_DPI
//    if (instance_state.source_addr.sin_addr.s_addr == recv_packet_dest_address.sin_addr.s_addr) {
//        printf("Addresses match\n");
//    }
//
//    if (instance_state.source_addr.sin_port == recv_packet_dest_address.sin_port) {
//        printf("Ports match\n");
//    }
//#endif
//
//    if ((instance_state.source_addr.sin_port == recv_packet_dest_address.sin_port)
//            & (instance_state.source_addr.sin_addr.s_addr == recv_packet_dest_address.sin_addr.s_addr)) {
//#ifdef DEBUG_DPI
//        printf("========Incoming Packet========\n");
//        printf("Packet Size (bytes): %d\n",ntohs(ip_packet->tot_len));
//        printf("Source Address: %s\n", (char *)inet_ntoa(recv_packet_source_address.sin_addr));
//        printf("Destination Address: %s\n", (char *)inet_ntoa(recv_packet_dest_address.sin_addr));
//        printf("Identification: %d\n", ntohs(ip_packet->id));
//        printf("Protocol: %d\n", ip_packet->protocol);
//        printf("TCP header size (bytes): %d\n", (tcp_packet->doff)<<2);
//        printf("Source Port: %d\n", ntohs(tcp_packet->source));
//        printf("Dest Port: %d\n", ntohs(tcp_packet->dest));
//        printf("SYN: %d\n", tcp_packet->syn);
//        printf("ACK: %d\n", tcp_packet->ack);
//        printf("SEQ num: %x\n", ntohl(tcp_packet->seq));
//        if (tcp_packet->ack) {
//            printf("ACK num: %u\n", ntohl(tcp_packet->ack_seq));
//        }
//        printf("\n");
//#endif

    rx_data_if.buffer_len = ntohs(ip_packet->tot_len) + sizeof(ether_header);
    rx_data_if.buffer_pos = 0;

    rx_data_if.buffer = (uint8_t *)(malloc(rx_data_if.buffer_len));
    memcpy(rx_data_if.buffer, buffer, rx_data_if.buffer_len);
    printf("Buffer len: %d\n", rx_data_if.buffer_len);

    return rx_data_if.buffer_len;
}

/*******************************************************************
 * TX Path
 ******************************************************************/

extern "C" void put_data(svBitVecVal *data, bool last, int padbytes) {
    uint8_t *dpi_vector = (uint8_t *)(data);
    int dpi_padbytes = last ? padbytes : 0;
    if (last) {
        printf("Padbytes is: %d\n", dpi_padbytes);
    }

    printf("Putting data in vector. Buffer: ");
    // push data into the vector backwards
    for (int i = (MAC_INTERFACE_W >> 3) - 1; i >= dpi_padbytes; i--) {
        printf("%hhx ", dpi_vector[i]);
        tx_data_if.buffer.push_back(dpi_vector[i]);
    }
    printf("\n");
    if (last) {
        send_on_socket();
    }
}

static void send_on_socket() {
    uint8_t *packet_buffer = tx_data_if.buffer.data();
    uint32_t buffer_len = tx_data_if.buffer.size();

    printf("========Outgoing packet========\n");
    printf("Length: %d\n", buffer_len);
    //printf("Packet contents\n");
    //print_wire_header(packet_buffer);

    int bytes;
    bytes = sim_backend->put_buf_on_io(tx_data_if.buffer);

    printf("Bytes sent: %d\n", bytes);
    printf("===============================\n");


    // after we've sent the data, clear the buffer
    tx_data_if.buffer.clear();
}

/*******************************************************************
 * Initialization
 ******************************************************************/

extern "C" void init_network_side_state() {
    instance_state.source_addr.sin_family = AF_INET;
    instance_state.source_addr.sin_port = 1234;
    inet_pton(AF_INET, "192.0.0.2", &instance_state.source_addr.sin_addr.s_addr);


//    if (USE_RAW == 1) {
//        init_with_raw_socket(&instance_state);
//        instance_state.source_addr.sin_family = AF_INET;
//        instance_state.source_addr.sin_port = 40002;
//        inet_pton(AF_INET, "127.0.0.1", &instance_state.source_addr.sin_addr.s_addr);
//    }
    // e0:07:1b:6f:fc:c1        
    instance_state.source_mac_addr[0] = 0x24;
    instance_state.source_mac_addr[1] = 0xbe;
    instance_state.source_mac_addr[2] = 0x05;
    instance_state.source_mac_addr[3] = 0xbf;
    instance_state.source_mac_addr[4] = 0x5b;
    instance_state.source_mac_addr[5] = 0x91;

    instance_state.has_syn_acked = 0;

    svBitVecVal buffer_data[MAC_INTERFACE_W>>5];
    for (int j = 0; j < MAC_INTERFACE_W >> 5; j++) {
        buffer_data[j] = 0;
    }
    rx_data_if.buffer_pos = 0;
    rx_data_if.buffer_len = 0;
    drive_rx_if(false, buffer_data, false, 0);
    
    if (BACKEND == FILE_IO) {
        printf("Using files backend\n");
        sim_backend = new FileIOTestingLib("hw_to_sw.txt", "sw_to_hw.txt");
    }
    else if (BACKEND == PCAP_TRACE){
        printf("Using PCAP trace backend with file %s\n", TRACE_FILE_PATH);

        TCPPcapTestingLib *pcap_testing = new TCPPcapTestingLib(TRACE_FILE_PATH, instance_state); 
        sim_backend = pcap_testing;
    }
    else {
        printf("Invalid backend\n");
        finish_simulation();
    }
    printf("Initialized socket state\n");
}

void finish_simulation() {
    delete sim_backend;
    finish_from_c();
}
