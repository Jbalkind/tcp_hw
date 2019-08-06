# TCP Hardware

An end-to-end prototype of the fastpath, dataplane TCP operations in hardware

## Testing
We test using a TCP stack running in a different process. We are using PicoTCP. The 
test code and some DPI code in this repo interface through files. The test software 
can be found in [this repo](https://github.com/HelloKayT/tcp-over-fd).


1. Source `settings.sh` in the project root directory

2. Build picoTCP and the client program wherever you cloned it to

3. `cd` into the `build` directory right under the project root director

4. Run `make build`

5. Run `make run`

6. Run your picoTCP client program

## Debugging

Run Wireshark and sniff all TCP packets to see the flow. It's pretty good at indicating where the TCP is broken. If it seems like the network stack is broken (it probably is) instead of anything you added, just slack Katie :)

