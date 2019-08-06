import logging
import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb.log import SimLog

addr_format_str = "{0:03b}"

async def reset(dut):
    dut.rst.setimmediatevalue(0)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

@cocotb.test()
async def mem_test(dut):
    log = SimLog("cocotb.tb")
    log.setLevel(logging.DEBUG)

    # Create the interfaces
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    dut.wr_en_a.setimmediatevalue(0)
    dut.wr_addr_a.setimmediatevalue(0)
    dut.wr_data_a.setimmediatevalue(0)

    dut.rd_req_en_a.setimmediatevalue(0)
    dut.rd_req_addr_a.setimmediatevalue(0)

    dut.rd_resp_rdy_a.setimmediatevalue(0)

    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    ref_mem = [0] * 8

    await reset(dut)
    await RisingEdge(dut.clk)

    log.info("Start basic write and read test")
    # Try to write all the addresses
    addr = BinaryValue(value=0, n_bits=3)
    for i in range(0, 8):
        dut.wr_en_a.value = 1
        addr.binstr = addr_format_str.format(i)
        dut.wr_addr_a.value = addr
        dut.wr_data_a.value = BinaryValue(value=0xdeadbeef + i, n_bits=32)
        ref_mem[i] = BinaryValue(value=0xdeadbeef + i, n_bits=32)
        await RisingEdge(dut.clk)

    dut.wr_en_a.value = 0
    addr.integer = 0
    dut.wr_addr_a.value = addr

    await RisingEdge(dut.clk)

    # start the first read
    dut.rd_req_en_a.value = 1
    addr.binstr = addr_format_str.format(0)
    dut.rd_req_addr_a.value = addr
    dut.rd_resp_rdy_a.value = 1

    # Make sure we can always read when wr en is low
    await ReadOnly()
    assert(dut.rd_resp_rdy_a.value == 1)

    # Try to read everything back
    for i in range(1, 8):
        await RisingEdge(dut.clk)
        dut.rd_req_en_a.value = 1
        addr.binstr = addr_format_str.format(i)
        dut.rd_req_addr_a.value = addr
        dut.rd_resp_rdy_a.value = 1
        await ReadOnly()
        assert(dut.rd_resp_val_a.value == 1)
        if (dut.rd_resp_data_a.value != ref_mem[i-1]):
            await RisingEdge(dut.clk)
            raise RuntimeError

    # check the last read
    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 0
    await ReadOnly()
    assert(dut.rd_resp_val_a.value == 1)
    assert(dut.rd_resp_data_a.value == ref_mem[7])

    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 0
    # make sure the read val clears
    await ReadOnly()
    assert(dut.rd_resp_val_a.value == 0)
    await RisingEdge(dut.clk)

    log.info("Try to read and write independent addresses")
    dut.rd_req_en_a.value = 1
    dut.wr_en_a.value = 1
    addr.binstr = addr_format_str.format(0)
    dut.wr_addr_a.value = addr
    dut.wr_data_a.value = BinaryValue(value=0xcafefeed, n_bits=32)
    ref_mem[0] = BinaryValue(value=0xcafefeed, n_bits=32)
    addr.binstr = addr_format_str.format(4)
    dut.rd_req_addr_a.value = addr

    # make sure we can actually read and write from different addresses at the
    # same time
    await ReadOnly()
    assert (dut.rd_req_rdy_a.value == 1) and (dut.wr_rdy_a.value == 1)

    # okay wait for the operation to go through and then check the read result
    await RisingEdge(dut.clk)
    dut.rd_resp_rdy_a.value = 1
    dut.rd_req_en_a.value = 0
    dut.wr_en_a.value = 0

    await ReadOnly()
    assert (dut.rd_resp_val_a.value == 1)
    assert (dut.rd_resp_data_a.value == ref_mem[4])

    # also check that the write was okay by reading it back
    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 1
    addr.binstr = addr_format_str.format(0)
    dut.rd_req_addr_a.value = addr
    await ReadOnly()
    assert (dut.rd_req_rdy_a.value == 1)

    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 0
    dut.rd_resp_rdy_a.value = 1

    await ReadOnly()
    assert(dut.rd_resp_val_a.value == 1)
    assert(dut.rd_resp_data_a.value == ref_mem[0])

    log.info("Try to read and write the same address")
    await RisingEdge(dut.clk)
    dut.wr_en_a.value = 1
    dut.rd_req_en_a.value = 1
    addr.binstr = addr_format_str.format(2)
    dut.wr_addr_a.value = addr
    dut.wr_data_a.value = BinaryValue(value=0xfeedfeed, n_bits=32)
    ref_mem[2] = BinaryValue(value=0xfeedfeed, n_bits=32)
    dut.rd_req_addr_a.value = addr

    await ReadOnly()
    assert(dut.wr_rdy_a == 1)
    assert(dut.rd_req_rdy_a == 0)

    await RisingEdge(dut.clk)
    dut.wr_en_a.value = 0
    # check that the read can go through
    await ReadOnly()
    assert(dut.rd_req_rdy_a == 1)

    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 0
    await ReadOnly()
    assert(dut.rd_resp_val_a.value == 1)
    assert(dut.rd_resp_data_a.value == ref_mem[2])

    log.info("Test blocking reads")

    # Issue read and block
    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 1
    addr.binstr = addr_format_str.format(5)
    dut.rd_req_addr_a.value = 5
    dut.rd_req_en_a.value = 1
    await ReadOnly()
    assert(dut.rd_req_rdy_a.value == 1)

    await RisingEdge(dut.clk)
    dut.rd_resp_rdy_a.value = 0
    await ReadOnly()
    # make sure we're backpressuring the input
    assert(dut.rd_req_rdy_a.value == 0)
    assert(dut.rd_resp_val_a.value == 1)

    await RisingEdge(dut.clk)
    # Make sure that even if we set a read request, it won't change the output
    dut.rd_req_en_a.value = 1
    addr.binstr = addr_format_str.format(1)
    dut.rd_req_addr_a.value = addr
    await ReadOnly()
    # make sure we're backpressuring the input
    assert(dut.rd_req_rdy_a.value == 0)
    assert(dut.rd_resp_val_a.value == 1)

    await RisingEdge(dut.clk)
    # okay actually take the response now
    dut.rd_resp_rdy_a.value = 1
    await ReadOnly()
    # check that the response is for the first request and not the second
    assert(dut.rd_resp_val_a.value == 1)
    assert(dut.rd_resp_data_a.value == ref_mem[5])
    # check that we accepted the next read request in this cycle
    assert(dut.rd_req_rdy_a.value == 1)

    await RisingEdge(dut.clk)
    dut.rd_req_en_a.value = 0
    dut.rd_resp_rdy_a.value = 1
    await ReadOnly()
    # check that the response is for the second request
    assert(dut.rd_resp_val_a.value == 1)
    assert(dut.rd_resp_data_a.value == ref_mem[1])

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
