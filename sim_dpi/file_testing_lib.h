#ifndef FILE_TESTING_LIB_H
#define FILE_TESTING_LIB_H

#include "testing_utils.h"
#include <sys/time.h>

struct pcap_file_header {
    uint32_t magic_number;   /* magic number */
    uint16_t version_major;  /* major version number */
    uint16_t version_minor;  /* minor version number */
    int32_t  thiszone;       /* GMT to local correction */
    uint32_t sigfigs;        /* accuracy of timestamps */
    uint32_t snaplen;        /* max length of captured packets, in octets */
    uint32_t network;        /* data link type */
};

struct pcap_pkthdr {
    uint32_t ts_sec;
    uint32_t ts_usec;
    uint32_t caplen; /* length of portion present */
    uint32_t len;    /* length this packet (off wire) */
};

void init_with_fds(sock_state *instance_state);
int get_buffer_from_fd(sock_state *instance_state, unsigned char *buffer);
int put_buffer_to_fd(sock_state *instance_state, unsigned char *buffer, uint32_t buffer_len);
int read_pcap_record(FILE *pcap_file, unsigned char *buffer);
int write_pcap_record(FILE *pcap_file, unsigned char *buffer, uint32_t buffer_len);
void writePCAPHeader(FILE * f);

#endif
