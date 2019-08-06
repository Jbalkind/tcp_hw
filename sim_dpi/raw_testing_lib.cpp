#include <stdio.h>
#include <stdlib.h> //for exit(0);
#include <errno.h> //For errno - the error number
#include <string.h> //memset
#include <netinet/ip.h>	//Provides declarations for ip header
#include <netinet/tcp.h>	//Provides declarations for tcp header
#include <arpa/inet.h>
#include <net/ethernet.h> 
#include <net/if.h>
#include <sys/ioctl.h>
#include <linux/if_packet.h>

#include "flows.h"
#include "raw_testing_lib.h"

int get_netif_index(int socket, const char *if_name) {
    struct ifreq ifr;
    size_t if_name_len = strlen(if_name);
    if (if_name_len < sizeof(ifr.ifr_name)) {
        memcpy(ifr.ifr_name, if_name, if_name_len);
        ifr.ifr_name[if_name_len] = 0;
    } else {
        fprintf(stderr, "interface name is too long\n");
        exit(1);
    }
    if (ioctl(socket, SIOCGIFINDEX, &ifr) == -1) {
        perror("ioctl");
        exit(1);
    }
    int ifindex=ifr.ifr_ifindex;

    return ifindex;
}

void init_with_raw_socket(sock_state *instance_state) {
    instance_state->recv_sock = socket (AF_PACKET, SOCK_DGRAM, htons(ETH_P_IP));
    if(instance_state->recv_sock == -1) {
        //socket creation failed, may be because of non-root privileges
        perror("Failed to create socket");
        exit(1);
    }
    // bind recv socket
    const char* if_name = "lo";
    int ifindex = get_netif_index(instance_state->recv_sock, if_name);
    struct sockaddr_ll addr;
    memset(&addr, 0, sizeof(struct sockaddr_ll));
    addr.sll_family = AF_PACKET;
    addr.sll_ifindex = ifindex;
    addr.sll_protocol = htons(ETH_P_IP);
    
    if (bind(instance_state->recv_sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        perror("bind");
        exit(1);
    }
    
    instance_state->send_sock = socket (AF_INET, SOCK_RAW, IPPROTO_RAW);
    if (instance_state->send_sock == -1) {
        //socket creation failed, may be because of non-root privileges
        perror("Failed to create send socket");
        exit(1);
    }

    //IP_HDRINCL to tell the kernel that headers are included in the packet
	int one = 1;
	const int *val = &one;
    if (setsockopt (instance_state->send_sock, IPPROTO_IP, IP_HDRINCL, val, sizeof (one)) < 0) {
		perror("Error setting IP_HDRINCL for send socket");
		exit(0);
	}
}

int get_buffer_from_raw_socket(sock_state *instance_state, unsigned char *buffer) {
    int packet_size = recvfrom(instance_state->recv_sock, buffer, 65536, MSG_DONTWAIT, NULL, NULL);
    if (packet_size == -1) {
        if (errno == EAGAIN || errno == EWOULDBLOCK) {
            return 0;
        }
        else {
            exit(1);
        }
    }
    return packet_size;
}

int put_buffer_to_raw_socket(sock_state *instance_state, unsigned char *buffer, uint32_t buffer_len) {
    struct sockaddr_in *dest_address = &(instance_state->dest_addr);
    uint32_t total_packet_len = buffer_len;
    int bytes = sendto(instance_state->send_sock, buffer, total_packet_len, 0,
          (struct sockaddr *)dest_address, sizeof(struct sockaddr_in));
    
    if (bytes < 0) {
        perror("Error sending");
        exit(0);
    }
    return bytes;
}
