# Brief documentation for engine trace testing

This is meant to test just the TCP engine as much as possible. However, the TCP
engine is built with being connected to a NoC in mind, especially for payload
copying. As a result, some things may be stubbed out and such. Eventually,
things should be reorged, so the NoC communicating bits sit in the TCP tile
rather than the TCP engine itself. 

- The overall testbench isn't going to check for data correctness. The
  correctness of those modules should be tested in other places. Instead, it
  will check that it receives the expected payload pointers

- Since there is no reliance on correct data, the NoC ports that the receive
  pipe uses to write payloads go to a spoof writer that just drains the NoC and
  immediately returns the WR\_RESP flit

- Copying from the temporary buffer just returns 0s. Trying to free the given
  slab does nothing. Ready is tied to 1

- The echo app is a spoof that is just going to increment pointers in the RX and
  TX buffers as appropriate
