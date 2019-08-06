#ifndef DPI_TESTING_LIB_HPP
#define DPI_TESTING_LIB_HPP
#include <cstdint>

class DPITestingLib {
    public:
        DPITestingLib(){ };

        virtual std::vector<uint8_t> get_buf_fr_io() = 0;
        virtual int put_buf_on_io(std::vector<uint8_t> pkt_buf) = 0;
};

#endif
