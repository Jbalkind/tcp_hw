#ifndef FILE_IO_TESTING_LIB_HPP
#define FILE_IO_TESTING_LIB_HPP

#include <vector>
#include <cstdint>
#include <string>
#include "dpi_testing_lib.hpp"

class FileIOTestingLib: public DPITestingLib {
    public: 
        FileIOTestingLib(std::string send_file_name, std::string recv_file_name);
    
        std::vector<uint8_t> get_buf_fr_io() override;
        int put_buf_on_io(std::vector<uint8_t> pkt_buf) override;

    private:
        FILE *send_file;
        FILE *recv_file;
};

#endif
