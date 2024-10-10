import socket
import json
import time
import random
from threading import Thread,Lock

HOST = '0.0.0.0'  # 监听所有可用的接口
PORT = 8001  # 端口号
MESSAGE_SIZE = 980  # 消息大小
MAX_MESSAGES = 2000  # 最大消息发送次数
INITIAL_HEARTBEAT_INTERVAL = 10  # 初始心跳间隔（秒）
heartbeat_interval = INITIAL_HEARTBEAT_INTERVAL  # 当前心跳间隔
rtt=1
# 记录最后接收到的心跳消息的序号
last_received_number = 0
# 记录等待次数
break_times = 0
# 创建一个锁对象
lock = Lock()
def send_heartbeat(client_socket):
    global last_received_number
    global heartbeat_interval
    global rtt
    while True:
        try:
           # 尝试加锁，失败 另一个线程直接不走了with lock:
              time.sleep(heartbeat_interval)
              msg = {
                  'number': last_received_number,
                  'time': time.time() * 1000,
                  'break': break_times,
                  'message': 'heartbeat'
              }
              msg_str = json.dumps(msg)
              send_time=time.perf_counter()
              client_socket.sendall(msg_str.encode('utf-8'))
              data = client_socket.recv(1024)
              if not data:
                  break
              receive_time=time.perf_counter()
              rtt=receive_time-send_time
              if rtt>0.9:
                  heartbeat_interval=max(heartbeat_interval-30,10)
              elif rtt<0.7:
                  heartbeat_interval+=30
              print(f"hb:{heartbeat_interval},rtt:{rtt}")

        except json.JSONDecodeError:
            print("Received non-JSON data")
        except Exception as e:
            print(f"Error in receiving: {e}")
            break

    client_socket.close()
    print("Client disconnected.")

def send_messages(client_socket):
    time.sleep(1)
    global last_received_number, break_times, heartbeat_interval
    print(last_received_number)
    message_count = last_received_number + 1
    start_time = time.time()

    try:
        while message_count <= MAX_MESSAGES and (time.time() - start_time) < 24 * 3600:
            # with lock:
            message = {
                'number': message_count,
                'time': time.time() * 1000,
                'break': break_times,
                'message': 'X' * MESSAGE_SIZE
            }
            message_str = json.dumps(message)
            send_time=time.perf_counter()
            client_socket.sendall(message_str.encode('utf-8'))
            print(f'Sent message {message_count} , break times {break_times}')
            data = client_socket.recv(1024)
            if not data:
                break
            receive_time=time.perf_counter()
            rtt=receive_time-send_time
            if rtt>0.9:
                heartbeat_interval=max(heartbeat_interval-30,10)
            elif rtt<0.7:
                heartbeat_interval+=30
            print(f"hb:{heartbeat_interval},rtt:{rtt}")
            message = json.loads(data.decode('utf-8'))
            print(f"Received message: {message}")
            # 如果是心跳包，更新最新的接收序号
            if message.get("type") == "heartbeat":
                last_received_number = int(message.get("receive", last_received_number))
                print(f"Updated last received number to {last_received_number}")
            # 随机间隔 0.1 到 60 分钟
            interval = random.uniform(0.1, 10) * 1  # 转换为秒
            time.sleep(interval)
            message_count += 1

    except Exception as e:
        print(f"Error in sending: {e}")

    finally:
        client_socket.close()
        print("Client disconnected.")

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
        
        # 启动两个线程或进程，一个用于接收心跳包，一个用于发送消息
        receive_thread = Thread(target=send_heartbeat, args=(client_socket,))
        send_thread = Thread(target=send_messages, args=(client_socket,))
        
        receive_thread.start()
        send_thread.start()

        # 等待两个线程完成
        receive_thread.join()
        send_thread.join()
        print("Client connection handled, waiting for a new connection...")
        break_times += 1

if __name__ == "__main__":
    start_server()