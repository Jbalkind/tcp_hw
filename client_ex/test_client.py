import time
import socket

def main():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    s.connect(("localhost", 40002))
    
    print("Sending")
    
    for i in range(0, 16):
        s.sendall(bytes([97 + i]))

    print("Receiving")
    num_received = 0
    while num_received < 16:
        data = s.recv(1)
        data_as_string = repr(data)
        print(f"Received {data_as_string}")
        num_received += 1

    time.sleep(50)
    s.close();



if __name__ == "__main__":
    main()
