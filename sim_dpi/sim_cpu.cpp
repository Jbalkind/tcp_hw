// C++ includes
#include <string>
// C includes
#include <stdio.h>
#include <stdlib.h>
#include <arpa/inet.h>
#include "flows.h"
#include "testing_utils.h"
#include "svdpi.h"

std::string local_sim_scope;
struct flow_state flows[ACTIVE_FLOW_CNT];
extern "C" void write_flowid_lookup(svBitVecVal* new_lookup_entry, int new_flowid, int init_ack_num);

void set_new_flow(int flow_id, struct sock_state *instance_state) {
    // Do this 
    std::string orig_scope = svGetNameFromScope(svGetScope());
    printf("set new flow scope: %s\n", local_sim_scope.c_str());
    svSetScope(svGetScopeFromName(local_sim_scope.c_str()));
    struct flow_lookup * lookup = &((flows + (flow_id))->lookup_entry);

    svBitVecVal * dpi_flow_lookup = new svBitVecVal[4];

    lookup->host_ip = instance_state->source_addr.sin_addr.s_addr;
    lookup->dest_ip = instance_state->dest_addr.sin_addr.s_addr;
    lookup->host_port = instance_state->source_addr.sin_port;
    lookup->dest_port = instance_state->dest_addr.sin_port;
    lookup->flow_num = flow_id;

    // pack the DPI vector
    dpi_flow_lookup[2] = ntohl(lookup->host_ip);
    dpi_flow_lookup[1] = ntohl(lookup->dest_ip);
    dpi_flow_lookup[0] = (lookup->host_port << 16) + (lookup->dest_port);

    //printf("Host port is %d\n", lookup->host_port);
    //printf("Host address is %s\n", (char *)inet_ntoa(instance_state.source_addr.sin_addr));
    write_flowid_lookup(dpi_flow_lookup, flow_id, instance_state->init_ack_num);
    lookup->flow_drive_valid = true;
    svSetScope(svGetScopeFromName(orig_scope.c_str()));
}

extern "C" bool tick_flow_valid(int flow_id) {
    bool *valid_status = &((flows + flow_id)->lookup_entry.flow_drive_valid);
    bool result = *valid_status;
    *valid_status = false;

    return result;
}

// just get the write scope
extern "C" void local_init(void) {
    local_sim_scope = svGetNameFromScope(svGetScope());
    printf("local init scope: %s\n", local_sim_scope.c_str());
}
