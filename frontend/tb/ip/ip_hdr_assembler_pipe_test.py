import random 
import sys, os
import logging
from cocotb_test.simulator import run

import cocotb

def get_base_args():
    base_run_args = {}
    base_run_args["toplevel"] = "ip_hdr_assembler_pipe_wrap"
    base_run_args["module"] = "assembler_common_tests"

    base_run_args["verilog_sources"] = [
                os.path.join(".", "ip_hdr_assembler_pipe_wrap.sv"),
            ]

    base_run_args["sim_args"] = ["-voptargs=+acc"]
    compile_arg_string = f"{os.path.join(os.getcwd(), 'ip_testing.flist')}"
    base_run_args["compile_args"] = ["-f", f"{compile_arg_string}"]
    base_run_args["force_compile"] = True

    base_run_args["parameters"] = {
        "DATA_W": 512,
    }
    base_run_args["waves"] = 1
    base_run_args["gui"] = 1
    return base_run_args

def test_basic_hdr():
    base_run_args = get_base_args()
    base_run_args["testcase"] = "hdr_assembler_basic"
    base_run_args["sim_build"] = f"sim_build_assembler_basic"
    run(**base_run_args)

def test_valrdy():
    base_run_args = get_base_args()
    base_run_args["testcase"] = "hdr_assembler_vr_test"
    base_run_args["sim_build"] = f"sim_build_assembler_basic"
    run(**base_run_args)

