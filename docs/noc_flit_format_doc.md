# NoC Documentation

This document is a non-exhaustive description of the NoC header flit as well as how these flits are used to send store/load requests on the network on chip (NoC)

Header flit diagrams generated from: https://observablehq.com/@hellokayt/noc-header-flits

__Note__: we use NoC architecture terminology in this document, which overlaps with networking terminology, but the concepts are slightly different.

## NoC Overview

We are using a modified version of the 2-D mesh NoC from [OpenPiton](https://github.com/PrincetonUniversity/openpiton). The original documentation for that NoC is [here](http://parallel.princeton.edu/openpiton/docs/micro_arch.pdf). 

We expanded the width of the NoC to 256 bits and now only use one header flit that is a combination of all 3 header flits in the original format. Additionally, we expanded the width of the message length field originally in the 1st header flit and redefined some header flit fields that are unnecessary for our uses, since they were originally used for providing options to the caches. 

The origin (Tile 0, 0) is at the upper left corner. Moving right (or east) increments the X-coordinate. Moving down (or south) increments the Y-coordinate

## Header Flit Overview

The header flits contain the metadata for a packet on the NoC. If parsing/crafting header flits, please use the structs in `noc_defs.vh` rather than indexing out bits directly based on this documentation. 

### Header Flit 

This header flit is used for all packets on the NoC. The routers are only using the destination coordinates, fbits and message length. The rest of the fields are solely for the destination tile.



The routers themselves do not make use of the message type field and it is solely so the destination tile can behave appropriately.

![noc_header_flit](noc-header-flit.png "Header Flit Bitfields")



- __Dst Chip ID__ (14 bits): The Chip ID of the destination tile for this packet. For us, it will always be 0

- __Dst X Coord__ (8 bits): The X-coordinate of the destination tile for this packet

- __Dst Y Coord__ (8 bits): The Y-coordinate of the destination tile for this packet

- __FBits__ (4 bits): These are used for  routing when there are two modules sharing the same NoC port. The top bit will always be 1, which indicates it should be routed to the tile with the destination coordinates and then demultiplexed within the tile

- __Msg Len__ (22 bits): This is set to number of flits following this first header flit. Note that if the message is just this first header flit, this field is 0.

- __Msg Type__ (8 bits): This is set depending on what type of message is being sent. The following table has values of the requests that we currently use. Please use the defines in `noc_defs.vh` rather than using these values directly.

  | Message Type   | Value       | Define                   |
  | -------------- | ----------- | ------------------------ |
  | Load Request   | 8'd19/8'h13 | `MSG_TYPE_LOAD_MEM`      |
  | Store Request  | 8'd20/8'h14 | `MSG_TYPE_STORE_MEM`     |
  | Load Response  | 8'd24/8'h18 | `MSG_TYPE_LOAD_MEM_ACK`  |
  | Store Response | 8'd25/8'h19 | `MSG_TYPE_STORE_MEM_ACK` |

- __Address__ (48 bits): The address for the operation. For us, this is a memory address
- __Src Chip ID__ (14 bits):  The Chip ID of the source tile for this packet. For our purposes, this is always 0
- __Src X Coord__ (8 bits): The X-coordinate of the source of this packet
- __Src Y Coord__ (8 bits): The Y-coordinate of the source of this packet
- __FBits__ (4 bits):  These are used for  routing when there are two modules sharing the same NoC port. The top bit will always be 1, which indicates it should be routed to the tile with the destination coordinates and then demultiplexed within the tile
- __Data size__ (30 bits): Repurposed to specify the number of bytes in the operation. Originally used in OpenPiton for cache options. 
- __Padding__ (80 bits): Unused and just set to 0, could be repurposed later

#### Modifications

Versus the original OpenPiton format, we combined all 3 header flits into one flit, and we have gotten rid of the MSHR field and the options field. We shifted `msg type` down and expanded `msg length` to use the extra 14 bits.



## Memory Operations Overview

This section specifically describes the process of issuing memory operations from some source tile to the DRAM tile over the NoC. 

__Note__: Memory operations must be naturally aligned (8 byte ops can only be done on addresses that are a multiple of 8, 16 byte ops can only be done on addresses that are a multiple of 16, ect.). We also only support operations with sizes that are a multiple of 8. Memory operations can only extend across lines if addresses are aligned to a multiple of 256

### Payload Data Ordering

The DRAM tile uses the high byte as the smallest address and addresses increase moving to the lower bytes. It will use the high byte of the first payload packet as corresponding to the byte at the address specified in the header flit

### Store Operations

#### Request

A request packet for a store operation consists of all three header flits in order plus some number of payload flits, which only contain data. `msg type` should be set to `MSG_TYPE_STORE MEM`.

`msg len` in Header Flit 1 is set to reflect the number of payload flits in the packet. The actual value of `msg len` should be `# of payload flits` 

#### Response

After the DRAM tile completes the store request, it will send back a response packet. This packet is just Header Flit 1 with `msg type` set to `MSG_TYPE_STORE_MEM_ACK`. `msg len` will be 0, since there are no flits following it.

As of right now, the DRAM store will never fail, so you can just ignore this message as long as you sink it off the network. You possibly don't even need to wait for this response, but who knows, maybe memory operations will be able to fail in future iterations.

### Load Operations

#### Request

A request packet for a load operation consists of all three header flits in order. `msg type` will be set to `MSG_TYPE_LOAD_MEM`. `msg_len` will be 0.

#### Response

The response packet for a load operation will be Header Flit 1 followed by payload  flits which contain the data requested. `msg type` will be set to `MSG_TYPE_LOAD_MEM_ACK`. `msg len` will be the number of payload flits
