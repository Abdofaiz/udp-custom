import socket
import threading
import time

class GameUDPHandler:
    def __init__(self):
        self.active = True
        self.sockets = {}
        
        # Optimize for gaming traffic
        self.setup_gaming_ports()
        
    def setup_gaming_ports(self):
        for game, ports in self.GAME_PORTS.items():
            for port in ports:
                sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 65535)
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65535)
                # Enable fast packet processing
                sock.setsockopt(socket.IPPROTO_UDP, socket.SO_REUSEADDR, 1)
                sock.bind(('0.0.0.0', port))
                sock.setblocking(False)
                self.sockets[port] = sock
                print(f"[+] Optimized gaming port {port} for {game}")

    def start(self):
        try:
            print("[*] Starting optimized UDP handler for games")
            print("[*] Configured for: PUBG, FIFA")
            print("[*] Using BadVPN ports: 7100, 7200, 7300")
            
            # Start monitoring threads
            for port in self.sockets:
                thread = threading.Thread(target=self.handle_game_traffic, args=(port,))
                thread.daemon = True
                thread.start()
                
            while self.active:
                time.sleep(1)
                
        except KeyboardInterrupt:
            self.shutdown()
            
    def handle_game_traffic(self, port):
        sock = self.sockets[port]
        while self.active:
            try:
                data, addr = sock.recvfrom(4096)
                if data:
                    # Priority handling for game packets
                    self.process_game_packet(data, addr, port)
            except BlockingIOError:
                time.sleep(0.001)  # Minimal sleep for gaming
            except Exception as e:
                print(f"[-] Error on port {port}: {e}")

sudo python3 gaming_handler.py