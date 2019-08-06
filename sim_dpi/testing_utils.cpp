#include <stdio.h>
#include <stdlib.h> //for exit(0);
#include <errno.h> //For errno - the error number
#include <string.h> //memset
#include <netinet/ip.h>	//Provides declarations for ip header
#include <netinet/tcp.h>	//Provides declarations for tcp header
#include <arpa/inet.h>
#include <netinet/ether.h> 
#include <net/if.h>
#include <sys/ioctl.h>
#include <linux/if_packet.h>

#include "flows.h"
#include "testing_utils.h"
#include "raw_testing_lib.h"
#include "file_testing_lib.h"

/***********************************************************************************
 * Checksum functions
 **********************************************************************************/
unsigned short csum(unsigned short *ptr,int nbytes) 
{
	register long sum;
	unsigned short oddbyte;
	register short answer;

	sum=0;
	while(nbytes > 1) {
//        printf("%hx ", *ptr);
		sum+=*ptr++;
		nbytes-=2;
	}
	if(nbytes==1) {
		oddbyte=0;
		*((u_char*)&oddbyte)=*(u_char*)ptr;
		sum+=oddbyte;
	}
  //  printf("\n");

	sum = (sum>>16)+(sum & 0xffff);
	sum = sum + (sum>>16);
	answer=(short)~sum;
	
	return(answer);
}

// assumes the TCP header and the payload are in the buffer pointed to by tcp segment.
void add_tcp_checksum(uint8_t *tcp_segment, uint32_t payload_len, 
                      uint32_t source_addr, uint32_t dest_addr) {
    struct TCPChecksumHeader pseudo_header;
    struct tcphdr *tcp_header = (struct tcphdr *)tcp_segment;
    uint32_t tcp_header_len = tcp_header->doff << 2;
	uint8_t pseudogram[sizeof(struct TCPChecksumHeader) + tcp_header_len + payload_len];
    struct tcphdr *chksum_tcp_hdr = (struct tcphdr *)(pseudogram + sizeof(struct TCPChecksumHeader));
    uint16_t checksum;

    uint64_t given_checksum = tcp_header->check;

    pseudo_header.srcAddr = source_addr;
    pseudo_header.dstAddr = dest_addr;
    pseudo_header.zero = 0;
    pseudo_header.protocol = IPPROTO_TCP;
    pseudo_header.TCP_len = htons(tcp_header_len + payload_len);

	memcpy(pseudogram , (char*) &pseudo_header, sizeof (struct TCPChecksumHeader));
	memcpy(pseudogram + sizeof(struct TCPChecksumHeader), tcp_segment, tcp_header_len + payload_len);
    chksum_tcp_hdr->check = 0;

    checksum = csum( (unsigned short*) pseudogram, 
                   sizeof(struct TCPChecksumHeader) + tcp_header_len + payload_len);

    //if (checksum != given_checksum) {
    //    printf("Oops checksums don't match\n");
    //    printf("Checksum from SW is %hx\n", checksum);
    //    printf("Checksum from HW is %hx\n", given_checksum);
    //    tcp_header->check = checksum;
    //}
    tcp_header->check = checksum;

}

void add_ip_checksum(struct iphdr *ip_header) {
    ip_header->check = csum((unsigned short *)ip_header, ip_header->ihl << 2);
}

/***********************************************************************************
 * Internal struct/wire struct conversion
 **********************************************************************************/
void convert_tcp_header_to_external(struct tcp_header *internal_header, struct tcphdr *wire_header, 
                                    struct sock_state *state) {
    memcpy(wire_header, internal_header, sizeof(struct tcphdr));

    // flip some fields around to network order
    wire_header->source = htons(wire_header->source);
    wire_header->dest = htons(wire_header->dest);
    // because the flow doesn't think about the SYN-ACK
    wire_header->seq = htonl(wire_header->seq);
    wire_header->ack_seq = htonl(wire_header->ack_seq);
    wire_header->window = htons(5840);
}

void convert_ip_header_to_external(struct iphdr *internal_header, struct iphdr *wire_header) {
    memcpy(wire_header, internal_header, sizeof(struct iphdr));
   
    wire_header->tot_len = htons(wire_header->tot_len);
    //wire_header->saddr = htonl(wire_header->saddr);
    //wire_header->daddr = htonl(wire_header->daddr);
}

void convert_external_to_tcp_header(struct tcphdr *wire_header, struct tcp_header *internal_header,
                                    struct sock_state *state) {
    memcpy(internal_header, wire_header, sizeof(struct tcphdr));

    // because the flow doesn't think about the SYN-ACK, the ACK number is one ahead
    internal_header->ack_num = ntohl(internal_header->ack_num);
    // because the flow doesn't take into account the initial sequence number and SYNs are stupid
    // so you increment the sequence number
    internal_header->seq_num = ntohl(internal_header->seq_num);

    // flip around some fields to host order
    internal_header->src_port = ntohs(internal_header->src_port);
    internal_header->dst_port = ntohs(internal_header->dst_port);
    internal_header->win_size = ntohs(internal_header->win_size);
    
    // tack on and fill in the flowid...just 0 for now. There should be an actual hash table lookup
    // or something to fill in the flowid for multiflow situations
    internal_header->_hdrlen_rsvd_nonce = 5 << 4;
}

/***********************************************************************************
 * Struct filling
 **********************************************************************************/
void fill_ip_header(struct sock_state *state, struct iphdr *ip_header, uint32_t payload_len) {
	ip_header->ihl = 5;
	ip_header->version = 4;
	ip_header->tos = 0;
	ip_header->tot_len = htons(sizeof (struct iphdr) + sizeof (struct tcphdr) + payload_len);
	ip_header->id = htonl (54321);	//Id of this packet
	ip_header->frag_off = 0;
	ip_header->ttl = 255;
	ip_header->protocol = IPPROTO_TCP;
	ip_header->check = 0;		//Set to 0 before calculating checksum
	//inet_pton(AF_INET, "127.0.0.1", &(ip_header->saddr));
	//inet_pton(AF_INET, "127.0.0.1", &(ip_header->daddr));
	
	//Ip checksum
	ip_header->check = csum ((unsigned short *) ip_header, ip_header->ihl<<2);

}

void fill_tcp_header(struct sock_state *state, struct tcphdr *tcp_header, uint32_t seq_num, 
                    uint32_t ack_num, uint8_t syn, uint8_t ack, struct sockaddr_in * dest_addr) {
	// For the check sum
    struct TCPChecksumHeader psh;
	uint8_t pseudogram[sizeof(struct TCPChecksumHeader) + sizeof(struct tcphdr)];

	//TCP Header
	tcp_header->source = htons ((state->source_addr).sin_port);
	tcp_header->dest = htons (dest_addr->sin_port);
	tcp_header->seq = htonl(seq_num);
	tcp_header->ack_seq = htonl(ack_num);
    tcp_header->res1 = 0;
	tcp_header->doff = 5;	//tcp header size
	tcp_header->fin=0;
	tcp_header->syn=syn;
	tcp_header->rst=0;
	tcp_header->psh=0;
	tcp_header->ack=ack;
	tcp_header->urg=0;
    tcp_header->res2=0;
	tcp_header->window = htons (5840);	/* maximum allowed window size */
	tcp_header->check = 0;	//leave checksum 0 now, filled later by pseudo header
	tcp_header->urg_ptr = 0;
   
    // Do the actual checksum
    psh.srcAddr = (state->source_addr).sin_addr.s_addr;
    psh.dstAddr = (dest_addr->sin_addr).s_addr;
	psh.zero = 0;
	psh.protocol = IPPROTO_TCP;
	psh.TCP_len = htons(sizeof(struct tcphdr)); //strlen(data) );
    
	memcpy(pseudogram , (char*) &psh , sizeof (struct TCPChecksumHeader));
	memcpy(pseudogram + sizeof(struct TCPChecksumHeader) , tcp_header, sizeof(struct tcphdr)); 
	
    tcp_header->check = csum( (unsigned short*) pseudogram, 
                              sizeof(struct TCPChecksumHeader) + sizeof(struct tcphdr));
}

/***********************************************************************************
 * Verilog/C struct conversions
 **********************************************************************************/
void bitvec_to_tcp_header(svBitVecVal *bitvec, struct tcp_header *header_struct) {
    header_struct->src_port = bitvec[4] >> 16;
    header_struct->dst_port = bitvec[4] & 0xFFFF;
    header_struct->seq_num = bitvec[3];
    header_struct->ack_num = bitvec[2];
    header_struct->_hdrlen_rsvd_nonce = bitvec[1] >> 24;
    header_struct->flags = (bitvec[1] >> 16) & 0xFF;
    header_struct->win_size = bitvec[1] & 0xFFFF;
    header_struct->chksum = ntohs(bitvec[0] >> 16);
    header_struct->urg_pointer = bitvec[0] & 0xFFFF;
}

void bitvec_to_ip_header(svBitVecVal *bitvec, struct iphdr *header_struct) {
    header_struct->ihl = (bitvec[4] >> 28) & 0xF;
    header_struct->version = (bitvec[4] >> 24) & 0xF;
    header_struct->tos = (bitvec[4] >> 16) & 0xFF;
    header_struct->tot_len = bitvec[4] & 0xFFFF;
    header_struct->id = (bitvec[3] >> 16) & 0xFFFF;
    header_struct->frag_off = bitvec[3] & 0xFFFF;
    header_struct->ttl = (bitvec[2] >> 24) & 0xFF;
    header_struct->protocol = (bitvec[2] >> 16) & 0xFF;
    header_struct->check = bitvec[2] & 0xFFFF;
    header_struct->saddr = htonl(bitvec[1]);
    header_struct->daddr = htonl(bitvec[0]);

}

void tcp_header_to_bitvec(struct tcp_header *header_struct, svBitVecVal *bitvec) {
    bitvec[4] = (header_struct->src_port << 16) + header_struct->dst_port;
    bitvec[3] = header_struct->seq_num;
    bitvec[2] = header_struct->ack_num;
    bitvec[1] = (header_struct->_hdrlen_rsvd_nonce << 24) 
        + (header_struct->flags << 16) + (header_struct->win_size);
    bitvec[0] = (header_struct->chksum << 16) + header_struct->urg_pointer;
}

void data_swizzle_64_bitvec_to_c_buf(svBitVecVal *data_input, uint8_t *dest_buf) {
    uint32_t low_addr_bytes = data_input[1];
    uint32_t high_addr_bytes = data_input[0];

    uint8_t *temp_pointer = (uint8_t *)(&low_addr_bytes);

    dest_buf[0] = temp_pointer[3];
    dest_buf[1] = temp_pointer[2];
    dest_buf[2] = temp_pointer[1];
    dest_buf[3] = temp_pointer[0];

    temp_pointer = (uint8_t *)(&high_addr_bytes);
    dest_buf[4] = temp_pointer[3];
    dest_buf[5] = temp_pointer[2];
    dest_buf[6] = temp_pointer[1];
    dest_buf[7] = temp_pointer[0];

}

void data_swizzle_64_c_buf_to_dpi_longint(uint8_t *data_input, uint64_t *dest_buf) {
//    uint32_t low_addr_bytes = dest_buf[1];
//    uint32_t high_addr_bytes = dest_buf[0];
//
//    uint8_t *temp_pointer = (uint8_t *)(&low_addr_bytes);
//
//    temp_pointer[3] = data_input[0];
//    temp_pointer[2] = data_input[1];
//    temp_pointer[1] = data_input[2];
//    temp_pointer[0] = data_input[3];
//
//    temp_pointer = (uint8_t *)(&high_addr_bytes);
//    temp_pointer[3] = data_input[4];
//    temp_pointer[2] = data_input[5];
//    temp_pointer[1] = data_input[6];
//    temp_pointer[0] = data_input[7];

    uint8_t * temp_pointer = (uint8_t *)(dest_buf);
    for (int i = 0; i < 8; i++) {
        temp_pointer[i] = data_input[7-i];
    }
}
/***********************************************************************************
 * Control CPU emulation
 **********************************************************************************/
//void send_syn_ack(struct sock_state *state, struct sockaddr_in *recv_packet_source_address,
//                  struct tcphdr *recv_tcp_header) {
//    uint32_t packet_size = sizeof(struct ether_header) + sizeof(struct iphdr) + sizeof(struct tcphdr);
//    unsigned char syn_ack_packet[packet_size];
//    uint32_t next_ack_num = ntohl(recv_tcp_header->seq) + 1;
//    struct ether_header *eth_header = (struct ether_header *)(syn_ack_packet);
//    struct iphdr *ip_header = (struct iphdr *)(syn_ack_packet + sizeof(struct ether_header));
//    struct tcphdr *tcp_header = (struct tcphdr *)(syn_ack_packet + sizeof(struct ether_header)
//                                                    + sizeof(struct iphdr));
//    ip_header->saddr = state->source_addr.sin_addr.s_addr;
//    ip_header->daddr = recv_packet_source_address->sin_addr.s_addr;
//
//    memcpy(eth_header->ether_dhost, state->dest_mac_addr, ETHER_ADDR_LEN);
//    memcpy(eth_header->ether_shost, state->source_mac_addr, ETHER_ADDR_LEN);
//    eth_header->ether_type = htons(ETHERTYPE_IP);
//    
//
//    fill_ip_header(state, ip_header, 0);
//    fill_tcp_header(state, tcp_header, 0, next_ack_num, 1, 1, recv_packet_source_address);
//    
//    int bytes;
//    if (USE_RAW == 1) {
//        bytes = put_buffer_to_raw_socket(state, syn_ack_packet, packet_size);
//    }
//    else {
//        bytes = put_buffer_to_fd(state, syn_ack_packet, packet_size);
//    }
//    
//#ifdef DEBUG_DPI
//    printf("Packet Send. Length: %d\n", bytes);
//#endif
//    state->has_syn_acked = 1;
//    state->init_ack_num = ntohl(recv_tcp_header->seq) + 1;
//}

/***********************************************************************************
 * Printing
 **********************************************************************************/
void print_tcp_header(struct tcp_header * print_header) {
    printf("tcp src port: %d\n", print_header->src_port);
    printf("tcp dst port: %d\n", print_header->dst_port);
    printf("tcp seq num: %x\n", print_header->seq_num);
    printf("tcp ack num: %x\n", print_header->ack_num);
    printf("tcp hdr len: %x\n", print_header->_hdrlen_rsvd_nonce >> 4);
    printf("tcp rsved: %x\n", (print_header->_hdrlen_rsvd_nonce >> 1) & 0x7);
    printf("tcp flags: %x\n", print_header->flags);
    printf("tcp win size: %x\n", print_header->win_size);
    printf("tcp chksum: %x\n", print_header->chksum);
    printf("tcp urg pointer: %x\n", print_header->urg_pointer);
}

void print_ip_header(struct iphdr * print_header) {
    struct in_addr source_addr;
    struct in_addr dest_addr;

    source_addr.s_addr = print_header->saddr;
    dest_addr.s_addr = print_header->daddr;
    printf("ip ihl: %d\n", print_header->ihl);
    printf("ip version: %d\n", print_header->version);
    printf("ip tos: %d\n", print_header->tos);
    printf("ip tot len: %d\n", print_header->tot_len);
    printf("ip id: %d\n", print_header->id);
    printf("ip frag off: %d\n", print_header->frag_off);
    printf("ip ttl: %d\n", print_header->ttl);
    printf("ip protocol: %d\n", print_header->protocol);
    printf("ip checksum: %x\n", print_header->check);
    printf("ip source address: %s\n", (char *)inet_ntoa(source_addr));
    printf("ip dest address: %s\n", (char *)inet_ntoa(dest_addr));
}

void print_wire_header(uint8_t *packet_buffer) {
    struct ether_header *eth_hdr = (struct ether_header *)packet_buffer;
    struct iphdr *ip_packet = (struct iphdr *)(packet_buffer + sizeof(ether_header));
    struct tcphdr *tcp_packet = (struct tcphdr *)(packet_buffer + sizeof(ether_header) 
                                    +(ip_packet->ihl << 2));
    // Structs that contain source and dest IP addresses in the packets
    struct sockaddr_in source_socket_address, dest_socket_address;
    
    memset(&source_socket_address, 0, sizeof(source_socket_address));
    source_socket_address.sin_addr.s_addr = ip_packet->saddr;
    source_socket_address.sin_port = ntohs(tcp_packet->source);
    memset(&dest_socket_address, 0, sizeof(dest_socket_address));
    dest_socket_address.sin_addr.s_addr = ip_packet->daddr;
    dest_socket_address.sin_port = ntohs(tcp_packet->dest);
    
    printf("Packet Size (bytes): %d\n",ntohs(ip_packet->tot_len));
    printf("Source MAC: %s\n", ether_ntoa((struct ether_addr*)(eth_hdr->ether_shost)));
    printf("Dest MAC: %s\n", ether_ntoa((struct ether_addr*)(eth_hdr->ether_dhost)));
    printf("Source Address: %s\n", (char *)inet_ntoa(source_socket_address.sin_addr));
    printf("Destination Address: %s\n", (char *)inet_ntoa(dest_socket_address.sin_addr));
    printf("Identification: %d\n", ntohs(ip_packet->id));
    printf("Protocol: %d\n", ip_packet->protocol);
    printf("TCP header size (bytes): %d\n", (tcp_packet->doff)<<2);
    printf("Source Port: %d\n", ntohs(tcp_packet->source));
    printf("Dest Port: %d\n", ntohs(tcp_packet->dest));
    printf("SYN: %d\n", tcp_packet->syn);
    printf("ACK: %d\n", tcp_packet->ack);
    if (tcp_packet->ack) {
        printf("ACK num: %u\n", ntohl(tcp_packet->ack_seq));
    }
    printf("\n");
}

void handle_arp(DPITestingLib * backend, 
                struct sock_state *state, struct ether_arp *arp_req) {
    struct arphdr *arp_hdr = &(arp_req->ea_hdr);
    uint8_t resp_buffer[sizeof(struct ether_header) + sizeof(struct ether_arp)];
    struct ether_header *resp_eth = (struct ether_header *)(resp_buffer);
    struct ether_arp *resp_arp_resp = (struct ether_arp *)(resp_buffer + sizeof(struct ether_header));
    struct arphdr *resp_arp_hdr = &(resp_arp_resp->ea_hdr);

    // check that this is for the right protocol and is a request
    if ((ntohs(arp_hdr->ar_pro) != ETHERTYPE_IP) || (ntohs(arp_hdr->ar_op) != ARPOP_REQUEST)) {
        printf("ARP is not for IPv4 or is not a request\n");
        return;
    }

    // check that this is for our IP address
    if (memcmp(arp_req->arp_tpa, &(state->source_addr.sin_addr.s_addr), 4) != 0) {
        printf("ARP not for our IP addr\n");
        return;
    }

    // copy in the requester
    memcpy(state->dest_mac_addr, arp_req->arp_sha, ETHER_ADDR_LEN);

    // craft our response ethernet header
    memcpy(resp_eth->ether_dhost, arp_req->arp_sha, ETHER_ADDR_LEN);
    memcpy(resp_eth->ether_shost, state->source_mac_addr, ETHER_ADDR_LEN);
    resp_eth->ether_type = htons(ETHERTYPE_ARP);

    // craft our response arp header
    resp_arp_hdr->ar_hrd = htons(ARPHRD_ETHER);
    resp_arp_hdr->ar_pro = htons(ETHERTYPE_IP);
    resp_arp_hdr->ar_hln = 6;
    resp_arp_hdr->ar_pln = 4;
    resp_arp_hdr->ar_op = htons(ARPOP_REPLY);

    // craft the response arp body
    memcpy(resp_arp_resp->arp_sha, state->source_mac_addr, ETHER_ADDR_LEN);
    memcpy(resp_arp_resp->arp_spa, &(state->source_addr.sin_addr.s_addr), 4);
    memcpy(resp_arp_resp->arp_tha, arp_req->arp_sha, ETHER_ADDR_LEN);
    memcpy(resp_arp_resp->arp_tpa, arp_req->arp_spa, 4);
   
    int bytes;
    std::vector<uint8_t> resp_vec(resp_buffer,
                 resp_buffer + (sizeof(struct ether_header) + sizeof(struct ether_arp)));
    bytes = backend->put_buf_on_io(resp_vec);

    printf("ARP response sent. Length: %d\n", bytes);

}
