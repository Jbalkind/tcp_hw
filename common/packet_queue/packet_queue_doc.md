# Documentation for the packet queue

This is exactly what the title says. There are two modules. Here's the
high-level recap:
- `packet_queue.sv`: this is the queue itself with a FIFO interface, but
  also `dump_packet`, `cmt_packet`, and `curr_pkt_els` signals
- `packet_queue_controller.sv`: this is a controller that can handle setting the
  `dump_packet` and `cmt_packet` signals as appropriate as well as enqueueing
  the size of the packet to a queue. It is very important the size queue is kept
  in sync with the data queue (described below). It also takes care of dumping
  the data for the packet that should be dropped. 

## Packet Queue
This queue is a normal FIFO with an added commit pointer. Full is checked by
comparing the write pointer and the read pointer as usual, but empty is checked
by comparing the read pointer and commit pointer, so you can only read up to the
commit pointer. Here's the invariant for the pointers:

`rd_ptr` <= `cm_ptr` <= `wr_ptr`

- `rd_ptr`: points to the element with the next data to be read, unless the
  FIFO is empty

- `wr_ptr`: points to the next empty element that data should be written to,
  unless the FIFO is full. In this case, it still points to the next element
  that data should be written to, but it isn't empty, so data can't actually be
  written there

- `cm_ptr`: points to the start of the next uncommitted packet/the first
  element after the last committed packet unless the FIFO is full. In this case,
  it still points to element after the last committed packet, but the element
  won't yet be the next uncommitted packet

Here's how the extra signals are used:
- `dump_packet`: when this is set, the write pointer is set to the commit
  pointer, clearing the packet in progress

- `cmt_packet`: when this is set, `cm_ptr` is advanced to the `wr_ptr`.  This
  needs to be set when `wr\req` for the last element for the packet is set. 

- `curr_pkt_els`: this is the current number of elements that the current,
  uncommitted packet takes up. To get the size of the whole packet, it should be
  read in the cycle when `cmt_packet is set`

## Packet Queue Controller
This takes care of setting the `dump_packet` and `cmt_packet` signals, so it
can present a relatively standard queue interface. It includes both a read
interface for the data queue and the size queue, but both interfaces are
relatively standard.

The `dump_packet` signal is set if trying to enqueue data, but the queue is
already full. In this case, it will also drop the rest of the data for that
packet.

The `cmt_packet` signal is set when enqueuing the last data line in a packet or
frame. In this cycle, it also enqueues the packet size to the size queue.

### Using the size queue
It is expected that the data enqueued includes some sort of indication of last
element. When a last element is dequeued, the packet size queue should be read
in the same cycle. If you don't want to use the size queue, just dequeue
whenever it's not empty
