import random 
import sys, os
import logging

import scapy
from scapy.packet import Raw
from scapy.utils import PcapReader
from scapy.layers.inet import IP

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly, Combine, ClockCycles
from cocotb.triggers import with_timeout, Event, First, Join
from cocotb.log import SimLog
from cocotb.queue import Queue as cocoQueue
from cocotb.utils import get_sim_time

sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common")
from simple_padbytes_bus import SimplePadbytesFrame
from simple_padbytes_bus import SimplePadbytesBus
from simple_padbytes_bus import SimplePadbytesBusSource
from simple_padbytes_bus import SimplePadbytesBusSink

from simple_val_rdy import SimpleValRdyBus, SimpleValRdyBusSink

import ip_stream_format_test_hdr_bus as hdr_bus

class PacketQueueEntry():
    def __init__(self, pkt, timestamp):
        self.pkt = pkt
        self.timestamp = timestamp

class TB():
    def __init__(self, dut):
        self.CLOCK_CYCLE_TIME = 4
        self.dut = dut
        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        self.input_bus = SimplePadbytesBus(dut, {"val": "src_ip_format_rx_val",
                                        "data": "src_ip_format_rx_data",
                                        "padbytes": "src_ip_format_rx_padbytes",
                                        "last": "src_ip_format_rx_last",
                                        "timestamp": "src_ip_format_rx_timestamp",
                                        "rdy": "ip_format_src_rx_rdy"},
                                        data_width = 512)
        self.input_op = SimplePadbytesBusSource(self.input_bus, dut.clk)

        self.hdr_output_bus = hdr_bus.IPStreamFormatHdrBus(dut, {"val": "ip_format_dst_rx_hdr_val",
                                            "hdr": "ip_format_dst_rx_ip_hdr",
                                            "timestamp": "ip_format_dst_rx_timestamp",
                                            "rdy": "dst_ip_format_rx_hdr_rdy"})
        self.hdr_output_op = hdr_bus.IPStreamFormatHdrSink(self.hdr_output_bus, dut.clk)

        self.output_bus = SimplePadbytesBus(dut,
                {"val": "ip_format_dst_rx_data_val",
                 "rdy": "dst_ip_format_rx_data_rdy",
                 "data": "ip_format_dst_rx_data",
                 "last": "ip_format_dst_rx_last",
                 "padbytes": "ip_format_dst_rx_padbytes"},
                                      data_width = 512)
        self.output_op = SimplePadbytesBusSink(self.output_bus, dut.clk)

        self.packet_queue = cocoQueue()
        self.done_event = Event()

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

async def recv_hdr_task(tb, event, max_rand_delay=0):
    output_hdr = await tb.hdr_output_op.recv_resp()
    event.set(data=output_hdr)

async def recv_task(tb, event, max_rand_delay=0):
    output_data = await tb.output_op.recv_frame(max_rand_delay=max_rand_delay)
    event.set(data=output_data)

def get_IP_hdr(hdr_len):
    test_packet = IP()
    if (hdr_len > 60 or hdr_len < 20 or (hdr_len%4 != 0)):
        raise ValueError("Requested IP header length invalid")

    test_packet["IP"].flags = "DF"
    test_packet["IP"].dst = "198.0.0.7"
    test_packet["IP"].src = "198.0.0.5"

    # calculate how long the options have to be
    option_value_len = hdr_len - 20 - 4
    if hdr_len >= 24:
        option_value = bytearray([])
        if (option_value_len > 0):
            option_value.extend(bytearray([4]* option_value_len))
        test_packet["IP"].options = IPOption(option=IPOption(
            length=option_value_len,
            option=68, value=option_value))

    return test_packet

async def input_loop(tb, ip_hdr_size, max_rand_delay=0):
    basic_ip_hdr = get_IP_hdr(ip_hdr_size)
    data_generator = random.Random(0)
    # test different payload sizes
    for i in range(1, 256):
        cocotb.log.info(f"Sending payload with size {i}")
        payload = data_generator.randbytes(i)
        test_pkt = basic_ip_hdr/Raw(payload)
        data_buf = test_pkt.build()

        timestamp = int(get_sim_time(units="ns"))
        tb.dut.src_ip_format_rx_timestamp.setimmediatevalue(timestamp)

        tb.packet_queue.put_nowait(PacketQueueEntry(test_pkt, timestamp))

        await tb.input_op.send_buf(data_buf,
            max_rand_delay=max_rand_delay)

    tb.done_event.set()

async def output_loop(tb, max_rand_delay=0):
    while ((not tb.done_event.is_set()) 
        or (tb.done_event.is_set() and (not tb.packet_queue.empty()))):
        data_event = Event()
        hdr_event = Event()

        recv_hdr_coro = cocotb.start_soon(recv_hdr_task(tb, hdr_event))
        recv_data_coro = cocotb.start_soon(recv_task(tb, data_event))

        await Combine(recv_hdr_coro, recv_data_coro)
        hdr_bytes = hdr_event.data.hdr.buff
        timestamp = hdr_event.data.timestamp

        payload_bytes = data_event.data
        
        cocotb.log.info(f"Received payload with size {len(payload_bytes)}")
        full_packet = hdr_bytes + payload_bytes

        if tb.packet_queue.empty():
            raise RuntimeError("Somehow got a packet we didn't send")

        ref_queue_item = tb.packet_queue.get_nowait()
        resp_pkt = IP(full_packet)

        assert timestamp == ref_queue_item.timestamp
        assert resp_pkt == IP(ref_queue_item.pkt.build())


@cocotb.test()
async def hdr_strip_test_basic(dut):
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())
    dut.src_ip_format_rx_val.setimmediatevalue(0)
    dut.src_ip_format_rx_timestamp.setimmediatevalue(0)
    dut.src_ip_format_rx_data.setimmediatevalue(0)
    dut.src_ip_format_rx_last.setimmediatevalue(0)
    dut.src_ip_format_rx_padbytes.setimmediatevalue(0)

    dut.dst_ip_format_rx_hdr_rdy.setimmediatevalue(0)

    dut.dst_ip_format_rx_data_rdy.setimmediatevalue(0)

    await reset(dut)

    send_coro = cocotb.start_soon(input_loop(tb, 20))
    recv_coro = cocotb.start_soon(output_loop(tb))
    await Combine(send_coro, recv_coro)

@cocotb.test()
async def val_rdy_test(dut):
    tb = TB(dut)
    
    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())
    dut.src_ip_format_rx_val.setimmediatevalue(0)
    dut.src_ip_format_rx_timestamp.setimmediatevalue(0)
    dut.src_ip_format_rx_data.setimmediatevalue(0)
    dut.src_ip_format_rx_last.setimmediatevalue(0)
    dut.src_ip_format_rx_padbytes.setimmediatevalue(0)

    dut.dst_ip_format_rx_hdr_rdy.setimmediatevalue(0)

    dut.dst_ip_format_rx_data_rdy.setimmediatevalue(0)

    await reset(dut)

    cocotb.log.info("Test slow sender")
    send_coro = cocotb.start_soon(input_loop(tb, 20, max_rand_delay=6))
    recv_coro = cocotb.start_soon(output_loop(tb))
    await Combine(send_coro, recv_coro)

    cocotb.log.info("Test slow receiver")
    send_coro = cocotb.start_soon(input_loop(tb, 20))
    recv_coro = cocotb.start_soon(output_loop(tb, max_rand_delay=6))
    await Combine(send_coro, recv_coro)

    cocotb.log.info("Test slow both")
    send_coro = cocotb.start_soon(input_loop(tb, 20, max_rand_delay=4))
    recv_coro = cocotb.start_soon(output_loop(tb, max_rand_delay=4))
    await Combine(send_coro, recv_coro)


