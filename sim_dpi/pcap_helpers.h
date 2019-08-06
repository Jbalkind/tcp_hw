#ifndef PCAP_HELPERS_H
#define PCAP_HELPERS_H
#include <cstdint>
#include <stdio.h>

#define DEBUG_PCAP_HELPERS

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

int read_pcap_record(FILE *file, uint8_t *buffer);
int write_pcap_record(FILE *file, uint8_t *buffer, uint32_t buffer_len);

void writePCAPHeader(FILE * f);
int consumePCAPHeader(FILE *f);

#endif
