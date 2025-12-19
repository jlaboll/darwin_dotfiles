#!/usr/bin/env python3
"""
TCP Proxy Forwarder for Tart VMs

Forwards connections from the VM-facing interface (192.168.64.1) to a local proxy.
This allows VMs to use the host's Zscaler or other SSL-intercepting proxies.

Usage:
    python3 proxy-forwarder.py <listen_host> <listen_port> <target_host> <target_port>
    
Example:
    python3 proxy-forwarder.py 192.168.64.1 9001 127.0.0.1 9000
"""

import socket
import threading
import sys
import signal

running = True

def forward(src, dst, name=""):
    """Forward data from src socket to dst socket."""
    try:
        while running:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except (ConnectionResetError, BrokenPipeError, OSError):
        pass
    finally:
        try:
            src.close()
        except:
            pass
        try:
            dst.close()
        except:
            pass

def handle_client(client_sock, target_host, target_port):
    """Handle a client connection by creating a tunnel to the target."""
    try:
        target_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        target_sock.settimeout(30)
        target_sock.connect((target_host, target_port))
        target_sock.settimeout(None)
        
        # Create bidirectional forwarding
        t1 = threading.Thread(target=forward, args=(client_sock, target_sock, "client->target"))
        t2 = threading.Thread(target=forward, args=(target_sock, client_sock, "target->client"))
        t1.daemon = True
        t2.daemon = True
        t1.start()
        t2.start()
        t1.join()
        t2.join()
    except Exception as e:
        print(f"Connection error: {e}", file=sys.stderr)
    finally:
        try:
            client_sock.close()
        except:
            pass

def signal_handler(signum, frame):
    """Handle shutdown signals."""
    global running
    running = False
    print("\nShutting down...", file=sys.stderr)
    sys.exit(0)

def main():
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)
    
    listen_host = sys.argv[1]
    listen_port = int(sys.argv[2])
    target_host = sys.argv[3]
    target_port = int(sys.argv[4])
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    try:
        server.bind((listen_host, listen_port))
    except OSError as e:
        print(f"Failed to bind to {listen_host}:{listen_port}: {e}", file=sys.stderr)
        sys.exit(1)
    
    server.listen(10)
    server.settimeout(1)  # Allow periodic checking of running flag
    
    print(f"Proxy forwarder: {listen_host}:{listen_port} -> {target_host}:{target_port}", file=sys.stderr)
    
    while running:
        try:
            client_sock, addr = server.accept()
            t = threading.Thread(target=handle_client, args=(client_sock, target_host, target_port))
            t.daemon = True
            t.start()
        except socket.timeout:
            continue
        except Exception as e:
            if running:
                print(f"Accept error: {e}", file=sys.stderr)
    
    server.close()

if __name__ == "__main__":
    main()

