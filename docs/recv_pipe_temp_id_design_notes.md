# Receive Pipe Temp FlowID

This is a scheme to make bypassing easier for flows that haven't been assigned a flow ID yet. It's an optimization, because we can compare the full tuple, but this cuts down on the number of bits. It's also really only for the situation where a SYN hasn't been processed for a flow in the FSM engine yet.

## Stage Outline

	### Stage F (FlowID lookup)

- Do normal flowID lookup
- Also do temp flowID lookup
- Check if need to bypass from T stage

### Stage T (TCP state lookup)

	- If there's a normal flowID lookup, great, do lookup and nothing else
 - If there's not a normal flowID lookup, but there is a temp flow ID lookup, there's another thing in the pipe that's gonna cause a flowID allocation, but we need to track it, track all writebacks of TCP state
    - Do we need recv state? No, because this is only a problem when we have a duplicate SYN, so we need to get the SYN received state, so we don't accept the second SYN. If we see the second SYN, just drop
 - If there's not a normal flowID lookup or a temp flowID lookup, write a temp flowID 
   	- Because everything going to the FSM pipe will go in order, can use a circular counter
   	- Because there are a fixed number of pipeline stages, can guarantee the counter won't overflow

### FSM pipe

- When writing the flowID, also clear the temp

## Bypassing

- If there's a normal flowID lookup, do bypassing by flowID
  - Bypass receive state and TCP state by flowID
- If there's a temp flowID lookup, do bypassing by temp flowID
  - Bypass TCP state

