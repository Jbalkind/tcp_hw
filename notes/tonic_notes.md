# Tonic Overview

- Simulation uses some magic state initialization (force)
- The host software is expected to handle
  - Flow setup/teardown
  - DMA setup for buffers
  - Segmentation
- Unique flow IDs are provided to the engine by whatever is hooked up to it (a software driver probably)
- Tracking for flow control is done at the segment level in Tonic
  - This could actually be viable if you fix the size of the packet, and the standard unit of flow control becomes the packet. However, this isn't going to interoperate with normal TCP out of the box
- No IP layer provided, so we need to go find our own IP core
- No mapping between flow ID and meta data and vice versa
  - We need to able to go from flow ID to srcIP:port dstIP:port on the send side
    - This is a simple memory
  - We also need to be able to go from srcIP:port dstIP:port back to flowID on the receive side
    - This is trickier and has to be a CAM or a hash table
- No mapping between segment ID and memory address
  - We need a hardware version of the DMA ring buffer, which is essentially a FIFO with an extra pointer for sending

# Tonic Implementation

				### Non-idle FIFO

- Responsible for feeding in which flow ID should be next thru the pipeline
- There are 4 enqueue ports (essentially 4 events which make a flow ready to send)
  0. The main port, reenqueue the current flow that's coming out of the `dd_next` pipeline
  1. Fed from `dequeue_prop`. This is triggered if we've enqueued to the size of the max size of the buffer to the credit engine and the credit engine dequeues.
     - Logic is based off of `dp_fid_id`, is fed by the `tx_fid` coming out of the credit engine
  2. Fed from the `inc1` stage. This is triggered if there were too many packets outstanding to the remote host, and the remote host `ACK`'ed us
  3. Fed from `timeout`. Triggered by a timer in `timeout`. If we're totally stuck (filled buffer to credit engine and transmit buffer to the remote host), because we haven't received `ACK`'s, we need to retransmit

### DD (data engine): segment number generation

	#### DD Incoming stages:

- These are for receiving `ACK`'s
  - This is like its own separate pipeline that does bypassing and stuff
  - One of the user programmable modules is in here

#### DD Next:

- This is for calculating the segment to send
- Inputs are things like window size and segment number for a certain flow
  - The flow ID to use is selected by the [non-idle FIFO](#Non-idle-FIFO)
- `next_new_in` is the current segment number for that flow. When selecting the next segment number it:
  - Checks if there is a segment that needs to be retransmitted and does that first
  - Otherwise, it checks if the next sequence number is inside the window. If so, it should be transmitted
  - Otherwise, just issue an invalid
- The window calculation is only one cycle, so we can bypass straight from the output back in and there are no bubbles

#### Ctx Store

- There are two context store memories
- The way it's written, it's a giant vector with fields for different pieces of data

#### DD Output

- The engine outputs
  - Next segment number
  - Flow ID for the segment
  - Transmit ID for the segment + flow, which is a count of retransmits
- This data goes to a queue that feeds the credit engine

- There's a sequence of 5 regs between the data delivery engine and the credit engine

### CC (credit engine): choose segments to save

#### Enqueue

- Enqueue takes packets from DD and enqueues them

#### Transmit

- This stage does credit calculation for the flow to the remote host and sends if there is enough credit
- Like `dd_next`, the credit calculation only takes one cycle, so the output can be bypassed back to the input if needed