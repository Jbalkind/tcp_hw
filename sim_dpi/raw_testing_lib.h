#ifndef RAW_TESTING_LIB_H
#define RAW_TESTING_LIB_H

#include "testing_utils.h"

int get_netif_index(int socket, const char *if_name);

void init_with_raw_socket(sock_state *instance_state);
int get_buffer_from_raw_socket(sock_state *instance_state, unsigned char *buffer);
int put_buffer_to_raw_socket(sock_state *instance_state, unsigned char *buffer, uint32_t buffer_len);

#endif
