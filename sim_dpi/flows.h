#ifndef FLOWS_H
#define FLOWS_H
#include <stdint.h>
#include <boost/functional/hash.hpp> 

#define HOST_IP             0x12700000
#define BASE_DEST_IP        0x12800000
#define HOST_PORT           0x100
#define BASE_DEST_PORT      0x1000

#define ACTIVE_FLOW_CNT 4
#define NUM_PAYLOADS 16
                     
#define TCP_FIN           0b00000001
#define TCP_SYN           0b00000010
#define TCP_RST           0b00000100
#define TCP_PSH           0b00001000
#define TCP_ACK           0b00010000
#define TCP_URG           0b00100000
#define TCP_ECE           0b01000000
#define TCP_CWR           0b10000000

struct tcp_header {
    uint16_t src_port;
    uint16_t dst_port;
    uint32_t seq_num;
    uint32_t ack_num;
    // This is three fields mashed together, because they're not a nice number of bits
    // and bitfields in C are bleh
    uint8_t _hdrlen_rsvd_nonce;
    uint8_t flags;
    uint16_t win_size;
    uint16_t chksum;
    // Here just so everything aligns...really not actually helpful
    uint16_t urg_pointer;
} __attribute__((packed));

struct ip_hdr {
  uint8_t  ver_ihl;  // 4 bits version and 4 bits internet header length
  uint8_t  tos;
  uint16_t total_length;
  uint16_t id;
  uint16_t flags_fo; // 3 bits flags and 13 bits fragment-offset
  uint8_t  ttl;
  uint8_t  protocol;
  uint16_t checksum;
  uint32_t src_addr;
  uint32_t dst_addr;
} __attribute__((packed));

struct eth_hdr {
    uint8_t  dst_addr[6];
    uint8_t  src_addr[6];
    uint16_t eth_type;
} __attribute__((packed));

struct eth_vlan_hdr {
    uint8_t  dst_addr[6];
    uint8_t  src_addr[6];
    uint32_t vlan_tag;
    uint16_t eth_type;
} __attribute__((packed));

#define ETH_TYPE_IPV4 0x0800
#define ETH_TYPE_VLAN 0x8100

struct flow_lookup {
    uint32_t    host_ip;
    uint32_t    dest_ip;
    uint16_t    host_port;
    uint16_t    dest_port;
    uint32_t    flow_num;
    bool        flow_drive_valid;
} __attribute__((packed));

struct flow_payloads {
    uint8_t data[NUM_PAYLOADS];
    uint32_t num_sent;
    bool packet_drive_valid;
} __attribute__((packed));

struct flow_state {
    struct flow_lookup lookup_entry;
    struct flow_payloads payloads;
    //bool recv_drive_valid;
} __attribute__((packed));


struct sliding_win_state {
    uint32_t received_ack;
    uint32_t next_send;
    uint32_t dupack_cnt;
};

struct TCPChecksumHeader {
  uint32_t srcAddr;
  uint32_t dstAddr;
  uint8_t zero;
  uint8_t protocol;
  uint16_t TCP_len;
};


void set_new_flow(int flow_id, struct sock_state *instance_state);

struct TCPFlowTuple {
    // big endian values
    uint32_t my_ip;
    uint32_t their_ip;
    uint16_t my_port;
    uint16_t their_port;

    bool operator==(const TCPFlowTuple& flow_tuple) const
    {
		return (my_ip == flow_tuple.my_ip) && 
			   (their_ip == flow_tuple.their_ip) &&
			   (my_port == flow_tuple.my_port) &&
			   (their_port == flow_tuple.their_port);
    }
};

class TCPFlowTupleHash {
    public:
        size_t operator()(const TCPFlowTuple& flow_tuple) const {
			using boost::hash_value;
			using boost::hash_combine;

			// Start with a hash value of 0    .
			std::size_t seed = 0;

            // Modify 'seed' with boost
			hash_combine(seed, hash_value(flow_tuple.my_ip));
            hash_combine(seed, hash_value(flow_tuple.their_ip));
            hash_combine(seed, hash_value(flow_tuple.my_port));
            hash_combine(seed, hash_value(flow_tuple.their_port));

            // Return the result.
            return seed;
        }
};
#endif
