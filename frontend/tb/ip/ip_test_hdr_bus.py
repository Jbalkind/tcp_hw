
from cocotb_bus.bus import Bus
from cocotb.binary import BinaryValue
import random
import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")

from simple_val_rdy import SimpleValRdyBus, SimpleValRdyBusSink
class IPHdrFrame:
    def __init__(self, hdr=b'', timestamp=None):
        self.hdr = BinaryValue(value=hdr)
        self.timestamp = timestamp
    
    def __repr__(self):
        return (
        f"{type(self).__name__}(data={self.hdr.buff.hex()!r}, "
        f"timestamp={self.timestamp!r})")

class IPHdrBus(SimpleValRdyBus):
    _signalNames = ["val", "hdr", "timestamp", "rdy"]

    def __init__(self, entity, signals):
        for name in self._signalNames:
            if not name in signals:
                raise AttributeError(f"signals doesn't contain a value for key" \
                    f"{name}")
        super().__init__(entity, signals)

class IPHdrSink(SimpleValRdyBusSink):
    def __init__(self, bus, clk):
        self._clk = clk
        super().__init__(bus, clk)

    def _get_return_vals(self):
        return_vals = IPHdrFrame(hdr=bytes(self._bus.hdr.value.buff),
                                            timestamp = self._bus.timestamp.value)
        return return_vals
