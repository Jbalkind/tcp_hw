import random 
import sys, os
import logging

import scapy
from scapy.packet import Raw
from scapy.utils import PcapReader
from scapy.layers.inet import IP, UDP

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

from simple_val_rdy import SimpleValRdyBus

import ip_test_hdr_bus as hdr_bus
import ip_assembler_hdr_bus as in_hdr_bus

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

        self.hdr_input_bus = in_hdr_bus.IPAssemblerHdrBus(dut, 
                {"val": "src_assembler_req_val",
                 "src_ip": "src_assembler_src_ip_addr",
                 "dst_ip": "src_assembler_dst_ip_addr",
                 "payload_len": "src_assembler_data_payload_len",
                 "protocol": "src_assembler_protocol",
                 "timestamp": "src_assembler_timestamp",
                 "rdy": "assembler_src_req_rdy"})
        self.hdr_input_op = in_hdr_bus.IPAssemblerHdrSource(self.hdr_input_bus, dut.clk)

        self.data_input_bus = SimplePadbytesBus(dut, {"val": "src_assembler_data_val",
                                        "data": "src_assembler_data",
                                        "padbytes": "src_assembler_data_padbytes",
                                        "last": "src_assembler_data_last",
                                        "rdy": "assembler_src_data_rdy"},
                                        data_width = 512)
        self.data_input_op = SimplePadbytesBusSource(self.data_input_bus, dut.clk)

        self.hdr_output_bus = hdr_bus.IPHdrBus(dut, {"val": "assembler_dst_hdr_val",
                                            "hdr": "assembler_dst_ip_hdr",
                                            "timestamp": "assembler_dst_timestamp",
                                            "rdy": "dst_assembler_hdr_rdy"})
        self.hdr_output_op = hdr_bus.IPHdrSink(self.hdr_output_bus, dut.clk)

        self.output_bus = SimplePadbytesBus(dut,
                {"val": "assembler_dst_data_val",
                 "rdy": "dst_assembler_data_rdy",
                 "data": "assembler_dst_data",
                 "last": "assembler_dst_data_last",
                 "padbytes": "assembler_dst_data_padbytes"},
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

async def send_hdr_task(tb, hdr):
    payload_len = hdr["IP"].len - (hdr["IP"].ihl * 4)
    timestamp = int(get_sim_time(units="ns"))
    req_values = in_hdr_bus.IPAssemblerFrame(hdr["IP"].src, hdr["IP"].dst, payload_len,
            hdr["IP"].proto, timestamp)
    await tb.hdr_input_op.send_req(req_values)

async def send_data_task(tb, buf, max_rand_delay=0):
    await tb.data_input_op.send_buf(buf, max_rand_delay=max_rand_delay)

async def recv_hdr_task(tb, event, max_rand_delay=0):
    output_hdr = await tb.hdr_output_op.recv_resp(max_rand_delay=max_rand_delay)
    event.set(data=output_hdr)

async def recv_task(tb, event, max_rand_delay=0):
    output_data = await tb.output_op.recv_frame(max_rand_delay=max_rand_delay)
    event.set(data=output_data)

async def input_loop(tb, max_rand_delay = 0):
    basic_ip_hdr = get_IP_hdr()
    data_generator = random.Random(0)

    for i in range(1, 256):
        cocotb.log.info(f"Sending payload with size {i}")
        payload = UDP(sport=54321,dport=12345)/Raw(data_generator.randbytes(i))
        test_pkt = basic_ip_hdr/payload
        data_buf = test_pkt.build()
        test_pkt = IP(data_buf)
        hdr_len = (test_pkt["IP"].ihl * 4)

        timestamp = int(get_sim_time(units="ns"))

        tb.packet_queue.put_nowait(PacketQueueEntry(test_pkt, timestamp))

        hdr_coro = cocotb.start_soon(send_hdr_task(tb, test_pkt))
        data_coro = cocotb.start_soon(send_data_task(tb, data_buf[hdr_len:]))

        await Combine(hdr_coro, data_coro)

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
async def hdr_assembler_basic(dut):
    tb = TB(dut)

    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())
    dut.src_assembler_req_val.setimmediatevalue(0)
    dut.src_assembler_src_ip_addr.setimmediatevalue(0)
    dut.src_assembler_dst_ip_addr.setimmediatevalue(0)
    dut.src_assembler_data_payload_len.setimmediatevalue(0)
    dut.src_assembler_protocol.setimmediatevalue(0)
    dut.src_assembler_timestamp.setimmediatevalue(0)

    dut.src_assembler_data_val.setimmediatevalue(0)
    dut.src_assembler_data.setimmediatevalue(0)
    dut.src_assembler_data_last.setimmediatevalue(0)
    dut.src_assembler_data_padbytes.setimmediatevalue(0)

    dut.dst_assembler_hdr_rdy.setimmediatevalue(0)

    dut.dst_assembler_data_rdy.setimmediatevalue(0)

    await reset(dut)

    send_coro = cocotb.start_soon(input_loop(tb))
    recv_coro = cocotb.start_soon(output_loop(tb))

    await Combine(send_coro, recv_coro)

@cocotb.test()
async def hdr_assembler_vr_test(dut):
    tb = TB(dut)

    cocotb.start_soon(Clock(dut.clk, tb.CLOCK_CYCLE_TIME, units='ns').start())
    dut.src_assembler_req_val.setimmediatevalue(0)
    dut.src_assembler_src_ip_addr.setimmediatevalue(0)
    dut.src_assembler_dst_ip_addr.setimmediatevalue(0)
    dut.src_assembler_data_payload_len.setimmediatevalue(0)
    dut.src_assembler_protocol.setimmediatevalue(0)
    dut.src_assembler_timestamp.setimmediatevalue(0)

    dut.src_assembler_data_val.setimmediatevalue(0)
    dut.src_assembler_data.setimmediatevalue(0)
    dut.src_assembler_data_last.setimmediatevalue(0)
    dut.src_assembler_data_padbytes.setimmediatevalue(0)

    dut.dst_assembler_hdr_rdy.setimmediatevalue(0)

    dut.dst_assembler_data_rdy.setimmediatevalue(0)

    await reset(dut)
   
    cocotb.log.info("Test slow input")
    send_coro = cocotb.start_soon(input_loop(tb, max_rand_delay=6))
    recv_coro = cocotb.start_soon(output_loop(tb))
    await Combine(send_coro, recv_coro)

    await RisingEdge(dut.clk)

    cocotb.log.info("Test slow output")
    send_coro = cocotb.start_soon(input_loop(tb))
    recv_coro = cocotb.start_soon(output_loop(tb, max_rand_delay=6))
    await Combine(send_coro, recv_coro)
    await RisingEdge(dut.clk)

    cocotb.log.info("Test slow both")
    send_coro = cocotb.start_soon(input_loop(tb, max_rand_delay=4))
    recv_coro = cocotb.start_soon(output_loop(tb, max_rand_delay=4))
    await Combine(send_coro, recv_coro)



def get_IP_hdr():
    test_packet = IP()

    test_packet["IP"].flags = "DF"
    test_packet["IP"].dst = "198.0.0.7"
    test_packet["IP"].src = "198.0.0.5"
    test_packet["IP"].id = 0
    test_packet["IP"].frag_offset = 0;
    test_packet["IP"].ttl = 64

    return test_packet
