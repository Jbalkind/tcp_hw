# `chksum_calc` Documentation

This is some informal documentation for the `tx_checksum` module (renamed to `chksum_calc`)from [Corundum](https://github.com/ucsdsysnet/corundum) that we are using with some modifications

Bitfield diagrams generated from: https://observablehq.com/@hellokayt/tx_checksum-byte-ordering

__Modifications__: 

- Removed a declaration (`sum_reg_2`), because it wasn't used anywhere and was using an out of range index for 64 bits
- Redid all the for-loop and pipeline shifting stuff, so the complex logic isn't in a clocked always block

## Usage

### Data Ordering

The checksum module counts starting from the low order bits in each input line as exemplified in the two following input lines

__Input line 1__

![tx_checksum_input_1](tx_checksum_input_1.png "TX Checksum: 1st input line")

__Input line 2__

![tx_checksum_input_2](tx_checksum_input_2.png "TX Checksum: 2nd input line")

### Interface Usage

- Assert the command at the beginning
  - Valid: command is valid
  - Enable: enable inserting the checksum into the datastream
  - Offset: where in the datastream to insert to (2 is right for us)
    - __Note__: It should really be 4, but because of the data ordering we use versus the counting that the checksum module does, we end up at 2
  - Start: where in the datastream to start summing from (0 for us)
  - Init: value to start the checksum with (0 for us)
- Follow with the data, which includes the pseudoheader, the actual TCP header, and the payload. We use the following data ordering:
  - Within the fields, the big byte is in the high order bits
  - Within the payload, the lowest address is in the high order bits
    - The lowest-most address should be in the high order bits of the first payload line 
- The first data line and the command can be asserted in the same cycle