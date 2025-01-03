class GameUDPSettings:
    def __init__(self):
        # Optimized gaming ports
        self.GAME_PORTS = {
            'pubg': [10012, 17500],    # PUBG Mobile ports
            'fifa': [3659, 14000],     # FIFA ports
            'general': [7100, 7200, 7300]  # BadVPN default ports
        }
        
        # Gaming optimized settings
        self.GAMING_CONFIG = {
            'buffer_size': 4096,        # Optimized for fast-paced games
            'timeout': 3,               # Lower timeout for better response
            'keepalive': 2,            # Frequent keepalive for stability
            'priority_queue': True,     # Enable priority for game packets
            'max_latency': 100,        # Max acceptable latency (ms)
        } 