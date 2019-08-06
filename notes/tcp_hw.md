# Raw Sockets

### To-Do

- [x] __Try sending basic TCP flow setup (`SYN`/`SYNACK`)  __ 
  - Need to setup a command to instruct the kernel to drop all packets to a certain port, documented [here](https://serverfault.com/questions/387263/disable-kernel-processing-of-tcp-packets-for-raw-socket)
  - Also need to use `AF_PACKET` socket with a protocol specification of IP
- [x] __Configure AWS image__

  - Use licenses on XOR (rather than EE licenses)

  - [x] __Install VCS__

# Tonic Infrastructure Augmentations

### Design Decisions

- To have `ACK`s piggyback on sending packet, we need a 2 write port memory: sets are done by the receive pipeline on receiving a packet and clears are done by the sending pipeline on sending the packet with the `ACK` flag and number
  - This is maybe okay, because it's just a giant bitvector? So a bunch of 1 bit registers. It's easy enough to write the logic to make sure things don't conflict

	## Send Modifications

- Two main modifications
  1. Adding packet payload buffers
  2. Taking feedback from packet payload buffer to determine whether there are things to send
- For the payload buffer:
  * It's just a circular buffer that tracks the end of the queue (`ack`'ed vs un`ack`'ed packets), the start of the queue (where to enqueue), and the next packet to send
  * The next packet pointer will always be between start and end 
  * The packets between the end of the queue and the next send pointer are all packets in flight
  * The end of the queue pointer is moved by the receive pipeline on receiving ACKs. We should never get an ACK number lower than the sequence number of the packet we’re expecting an ACK for
  * The start of the queue pointer is moved by software enqueuing a packet

### Design Decisions

- Bitmap vs index store?

### To - Do

- [x] __Set up packet payload buffer__

  - Head pointer is based on calculation for `wnd_start_index` from Tonic

  - Send pointer is based on the `next_seq_index ` calculation (replicate it)
    - Tail pointer is driven by software

- [x] __Test packet payload buffer __ 
- [x] __Properly pipeline receive stage__
- [x] __Setup sliding window for simulated receiver__

- [x] __Use packet payload buffer empty to determine whether or not there are packets to send__
  - Feed this signal into `dd_next`, output ``FLOW_ID_NONE` if there is nothing to send
  - [x] __Fix bypassing to the next free pointer mem__
  
- [ ] __Use packet payload writes to insert into the `dd` sending FIFO__
  - This is an optimization
  - This should just be done with converting with an arbiter

# Combined

### To-Do

- [x] __Write DPI code to open raw socket on init__
- [x] __Write DPI code to respond to SYN__
- [ ] __Write DPI code to send packet thru raw socket__
- [ ] __Write DPI code to receive packet thru raw socket__
- [ ] __End-to-end test with simple key-value store__

 