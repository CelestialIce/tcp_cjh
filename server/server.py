import socket
import time
import random
import struct

def start_server(host='0.0.0.0', port=9090):
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((host, port))
    server_socket.listen(1)
    print(f"Server started on {host}:{port}")
    
    while True:
        print("Waiting for a new connection...")
        client_socket, addr = server_socket.accept()
        print(f"Connection from {addr}")

        message_size = 1000
        total_sent = 0
        sequence_number = 1  # Starting sequence number

        try:
            start_time = time.time()
            while total_sent < 2000 and (time.time() - start_time) < 24 * 3600:
                timestamp = time.time()
                
                # Debug output for the timestamp before packing
                print(f"[DEBUG] Sending sequence number: {sequence_number}, timestamp: {timestamp}")

                # Create the packet with sequence_number and the updated timestamp
                filler_data = b'x' * (message_size - 12)  # Adjust to maintain 1000 bytes total
                packet = struct.pack('!Id', sequence_number, timestamp) + filler_data

                client_socket.sendall(packet)
                total_sent += 1
                sequence_number += 1
                print(f"Sent message {total_sent} with sequence number {sequence_number - 1}, packet size: {len(packet)}")

                # Random interval between 0.1 to 10 seconds
                interval = random.uniform(0.1, 10)
                time.sleep(interval)
        except Exception as e:
            print(f"Error: {e}")
        finally:
            client_socket.close()
            print("Client disconnected, waiting for a new connection...")

if __name__ == "__main__":
    start_server()