from ipaddress import IPv4Address, v4_int_to_packed

from cocotb_bus.bus import Bus
from cocotb.binary import BinaryValue
import random
import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")

from simple_val_rdy import SimpleValRdyBus, SimpleValRdyBusSource

class IPAssemblerFrame:
    def __init__(self, src_ip, dst_ip, payload_len, protocol, timestamp=0):
        self.src_ip = IPv4Address(src_ip)
        self.dst_ip = IPv4Address(dst_ip)
        self.payload_len = payload_len
        self.protocol = protocol
        self.timestamp = timestamp

    def __repr__(self):
        return (
        f"{type(self).__name__}(src_ip={self.src_ip}, "
        f"dst_ip={dst_ip}, payload_len={self.payload_len}, "
        f"protocol={self.protocol}, timestamp={self.timestamp})"
        )

class IPAssemblerHdrBus(SimpleValRdyBus):
    _signalNames = ["val", "src_ip", "dst_ip", "payload_len", "protocol",
            "timestamp", "rdy"]

    def __init__(self, entity, signals):
        for name in self._signalNames:
            if not name in signals:
                raise AttributeError(f"signals doesn't contain a value for key" \
                    f"{name}")
        super().__init__(entity, signals)


class IPAssemblerHdrSource(SimpleValRdyBusSource):
    def __init__(self, bus, clk):
        self._clk = clk
        super().__init__(bus, clk)

    def _fill_bus_data(self, req_values):
        self._bus.src_ip.value = BinaryValue(value=req_values.src_ip.packed,
                n_bits=32)
        self._bus.dst_ip.value = BinaryValue(value=req_values.dst_ip.packed,
                n_bits=32)
        self._bus.payload_len.value = req_values.payload_len
        self._bus.protocol.value = req_values.protocol
        self._bus.timestamp.value = req_values.timestamp

