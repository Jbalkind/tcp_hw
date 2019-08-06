
import random 
import sys, os
import logging
from cocotb_test.simulator import run

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


def get_base_args():
    base_run_args = {}
    base_run_args["toplevel"] = "ip_stream_format_nopipe_wrap"
    base_run_args["module"] = "common_tests"

    base_run_args["verilog_sources"] = [
                os.path.join(".", "ip_stream_format_nopipe_wrap.sv"),
            ]

    base_run_args["sim_args"] = ["-voptargs=+acc"]
    compile_arg_string = f"{os.path.join(os.getcwd(), 'ip_stream_format_test.flist')}"
    base_run_args["compile_args"] = ["-f", f"{compile_arg_string}"]
    base_run_args["force_compile"] = True

    base_run_args["parameters"] = {
        "DATA_WIDTH": 512,
    }
    base_run_args["waves"] = 1
    base_run_args["gui"] = 1
    return base_run_args

def test_basic_hdr_strip():
    base_run_args = get_base_args()
    base_run_args["testcase"] = "hdr_strip_test_basic"
    base_run_args["sim_build"] = f"sim_build_nopipe_basic"
    run(**base_run_args)

def test_val_rdy():
    base_run_args = get_base_args()
    base_run_args["testcase"] = "val_rdy_test"
    base_run_args["sim_build"] = f"sim_build_nopipe_valrdy"
    run(**base_run_args)
