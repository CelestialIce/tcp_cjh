import socket
import json
import time
import random
from threading import Thread, Lock

HOST = '0.0.0.0'  # Listen on all available interfaces
PORT = 8001  # Port number
MESSAGE_SIZE = 980  # Message size
MAX_MESSAGES = 2000  # Maximum number of messages to send
INITIAL_HEARTBEAT_INTERVAL = 10  # Initial heartbeat interval (seconds)
heartbeat_interval = INITIAL_HEARTBEAT_INTERVAL  # Current heartbeat interval
rtt = 1
last_received_number = 0  # Record the last received heartbeat message number
break_times = 0  # Record disconnection times
lock = Lock()  # Create a lock object

def send_heartbeat(client_socket):
    global last_received_number, heartbeat_interval, rtt
    while True:
        try:
            time.sleep(heartbeat_interval)
            msg = {
                'number': last_received_number,
                'time': time.time() * 1000,
                'break': break_times,
                'message': 'heartbeat'
            }
            msg_str = json.dumps(msg)
            send_time = time.perf_counter()
            client_socket.sendall(msg_str.encode('utf-8'))
            data = client_socket.recv(1024)
            if not data:
                break
            receive_time = time.perf_counter()
            rtt = receive_time - send_time
            # Adjust the heartbeat interval based on RTT
            if rtt > 0.9:
                heartbeat_interval = max(heartbeat_interval - 30, 10)
            elif rtt < 0.7:
                heartbeat_interval += 30
            print(f"hb: {heartbeat_interval}, rtt: {rtt}")

        except json.JSONDecodeError:
            print("Received non-JSON data")
        except Exception as e:
            print(f"Error in receiving heartbeat: {e}")
            break

    client_socket.close()
    print("Heartbeat thread ended. Client disconnected.")

def send_messages(client_socket):
    time.sleep(1)
    global last_received_number, break_times, heartbeat_interval
    print(last_received_number)
    message_count = last_received_number + 1
    start_time = time.time()

    try:
        while message_count <= MAX_MESSAGES and (time.time() - start_time) < 24 * 3600:
            message = {
                'number': message_count,
                'time': time.time() * 1000,
                'break': break_times,
                'message': 'X' * MESSAGE_SIZE
            }
            message_str = json.dumps(message)
            send_time = time.perf_counter()
            client_socket.sendall(message_str.encode('utf-8'))
            print(f'Sent message {message_count}, break times {break_times}')
            data = client_socket.recv(1024)
            if not data:
                break
            receive_time = time.perf_counter()
            rtt = receive_time - send_time
            # Adjust the heartbeat interval based on RTT
            if rtt > 0.9:
                heartbeat_interval = max(heartbeat_interval - 30, 10)
            elif rtt < 0.7:
                heartbeat_interval += 30
            print(f"hb: {heartbeat_interval}, rtt: {rtt}")
            message = json.loads(data.decode('utf-8'))
            print(f"Received message: {message}")
            if message.get("type") == "heartbeat":
                last_received_number = int(message.get("receive", last_received_number))
                print(f"Updated last received number to {last_received_number}")
            # Random interval between 0.1 and 10 seconds
            interval = random.uniform(0.1, 10)
            time.sleep(interval)
            message_count += 1

    except Exception as e:
        print(f"Error in sending messages: {e}")

    finally:
        client_socket.close()
        print("Messages thread ended. Client disconnected.")

def start_server(host=HOST, port=PORT):
    global break_times
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_socket.bind((host, port))
    server_socket.listen(1)
    print(f"Server started on {host}:{port}")

    while True:
        print("Waiting for a new connection...")
        client_socket, addr = server_socket.accept()
        print(f"Connection from {addr}")

        # Launch two threads, one for sending heartbeat and one for sending messages
        receive_thread = Thread(target=send_heartbeat, args=(client_socket,))
        send_thread = Thread(target=send_messages, args=(client_socket,))
        
        receive_thread.start()
        send_thread.start()

        # Prioritize reconnection if there's any conflict or disconnection
        while receive_thread.is_alive() or send_thread.is_alive():
            try:
                time.sleep(1)
                # Check if client_socket is still connected, handle reconnection if needed
                if client_socket.fileno() == -1:  # -1 indicates a closed socket
                    print("Client socket closed unexpectedly, handling reconnection...")
                    break
            except Exception as e:
                print(f"Error during client handling: {e}")
                break

        # Ensure both threads are properly joined before continuing
        receive_thread.join()
        send_thread.join()
        print("Client connection handled, preparing for a new connection...")
        break_times += 1

if __name__ == "__main__":
    start_server()
