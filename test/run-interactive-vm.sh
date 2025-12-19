#!/bin/bash

# Launch an interactive macOS VM for manual testing
# Useful for debugging issues or exploring the test environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"

VM_NAME="dotfiles-interactive"
VM_USER="${VM_USER:-admin}"
VM_PASS="${VM_PASS:-admin}"

# Proxy configuration for Zscaler/corporate environments
VM_GATEWAY="192.168.64.1"
PROXY_FORWARD_PORT=9001
ZSCALER_PROXY_PORT=9000
PROXY_FORWARDER_PID=""
VM_PROXY_URL=""

# Start proxy forwarder if Zscaler is detected
start_proxy_forwarder() {
    if ! lsof -i :$ZSCALER_PROXY_PORT -sTCP:LISTEN >/dev/null 2>&1; then
        return 0
    fi
    
    echo "Detected Zscaler proxy, starting forwarder..."
    python3 "$SCRIPT_DIR/lib/proxy-forwarder.py" \
        "$VM_GATEWAY" "$PROXY_FORWARD_PORT" \
        "127.0.0.1" "$ZSCALER_PROXY_PORT" &
    PROXY_FORWARDER_PID=$!
    sleep 1
    
    if kill -0 $PROXY_FORWARDER_PID 2>/dev/null; then
        VM_PROXY_URL="http://$VM_GATEWAY:$PROXY_FORWARD_PORT"
        echo "Proxy forwarder running on $VM_PROXY_URL"
    else
        echo "Warning: Failed to start proxy forwarder"
        PROXY_FORWARDER_PID=""
    fi
}

# Cleanup on exit
cleanup() {
    if [[ -n "$PROXY_FORWARDER_PID" ]]; then
        kill $PROXY_FORWARDER_PID 2>/dev/null || true
    fi
}
trap cleanup EXIT

show_help() {
    echo "Interactive macOS VM for darwin_dotfiles testing"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -s, --shell TYPE Set default shell (bash or zsh)"
    echo "  -g, --gui        Start with GUI (default: headless with SSH)"
    echo "  -c, --clean      Delete existing VM and create fresh"
    echo "  --ssh            SSH into existing running VM"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start headless VM and SSH in"
    echo "  $0 -g                 # Start VM with GUI window"
    echo "  $0 -s zsh             # Start VM with zsh as default shell"
    echo "  $0 --ssh              # SSH into already running VM"
    echo "  $0 -c                 # Create fresh VM (deletes existing)"
    echo ""
}

# Parse arguments
GUI_MODE=false
SHELL_TYPE=""
CLEAN_MODE=false
SSH_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -g|--gui)
            GUI_MODE=true
            shift
            ;;
        -s|--shell)
            SHELL_TYPE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_MODE=true
            shift
            ;;
        --ssh)
            SSH_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
if ! command -v tart >/dev/null 2>&1; then
    echo "Error: Tart is not installed."
    echo "Run: ./test/setup-tart.sh"
    exit 1
fi

# Start proxy forwarder for Zscaler environments (unless SSH-only or GUI mode)
if [[ "$SSH_ONLY" != "true" && "$GUI_MODE" != "true" ]]; then
    start_proxy_forwarder
fi

# SSH into existing VM
if [[ "$SSH_ONLY" == "true" ]]; then
    if ! tart list | grep -q "$VM_NAME"; then
        echo "Error: VM '$VM_NAME' does not exist."
        echo "Start it first with: $0"
        exit 1
    fi
    
    VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || echo "")
    if [[ -z "$VM_IP" ]]; then
        echo "Error: Could not get VM IP. Is it running?"
        exit 1
    fi
    
    echo "Connecting to $VM_NAME at $VM_IP..."
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP"
    exit 0
fi

# Clean mode - delete existing VM
if [[ "$CLEAN_MODE" == "true" ]]; then
    if tart list | grep -q "$VM_NAME"; then
        echo "Stopping and deleting existing VM..."
        pkill -f "tart run $VM_NAME" 2>/dev/null || true
        sleep 2
        tart delete "$VM_NAME" 2>/dev/null || true
    fi
fi

# Create VM if it doesn't exist
if ! tart list | grep -q "$VM_NAME"; then
    echo "Creating VM: $VM_NAME"
    
    if ! tart list | grep -q "dotfiles-base"; then
        echo "Error: Base image 'dotfiles-base' not found."
        echo "Run: ./test/setup-tart.sh"
        exit 1
    fi
    
    tart clone dotfiles-base "$VM_NAME"
    echo "VM created: $VM_NAME"
fi

# GUI mode - just start the VM with display
if [[ "$GUI_MODE" == "true" ]]; then
    echo "Starting VM with GUI..."
    echo ""
    echo "VM Credentials:"
    echo "  Username: $VM_USER"
    echo "  Password: $VM_PASS"
    echo ""
    echo "NOTE: GUI mode does not auto-configure DNS/SSL."
    echo "For network issues, run in the VM:"
    echo "  sudo networksetup -setdnsservers 'Ethernet' 8.8.8.8 8.8.4.4"
    echo ""
    echo "To copy dotfiles to VM:"
    echo "  scp -r $DOTFILES_ROOT $VM_USER@\$(tart ip $VM_NAME):~/.darwin_dotfiles"
    echo ""
    tart run "$VM_NAME"
    exit 0
fi

# Headless mode - start VM and SSH in
echo "Starting VM in headless mode..."
tart run "$VM_NAME" --no-graphics &
VM_PID=$!

echo "Waiting for VM to boot..."
sleep 45

# Get VM IP
VM_IP=$(tart ip "$VM_NAME" 2>/dev/null || echo "")
if [[ -z "$VM_IP" ]]; then
    echo "Error: Could not get VM IP"
    kill $VM_PID 2>/dev/null
    exit 1
fi

echo "VM IP: $VM_IP"

# Wait for SSH
echo "Waiting for SSH to be ready..."
for i in {1..60}; do
    if sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$VM_USER@$VM_IP" "echo ready" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done

# Configure DNS (VM may inherit unreachable corporate DNS from host)
echo "Configuring DNS..."
sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" \
    "sudo networksetup -setdnsservers 'Ethernet' 8.8.8.8 8.8.4.4" >/dev/null 2>&1 || true

# Install SSL proxy certificates (e.g., Zscaler) from host to VM
# This handles corporate SSL inspection proxies
if security find-certificate -a -c "Zscaler" -p /Library/Keychains/System.keychain >/dev/null 2>&1; then
    echo "Installing Zscaler SSL certificate in VM..."
    cert_file="/tmp/dotfiles-test-zscaler-ca.pem"
    security find-certificate -a -c "Zscaler" -p /Library/Keychains/System.keychain > "$cert_file" 2>/dev/null
    sshpass -p "$VM_PASS" scp -o StrictHostKeyChecking=no "$cert_file" "$VM_USER@$VM_IP:/tmp/" >/dev/null 2>&1
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" \
        "sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dotfiles-test-zscaler-ca.pem" >/dev/null 2>&1 || true
    rm -f "$cert_file"
    echo "SSL certificate installed."
fi

# Configure proxy environment if forwarder is running
if [[ -n "$VM_PROXY_URL" ]]; then
    echo "Configuring proxy environment..."
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "cat >> ~/.zprofile" << PROXYEOF
# Proxy configuration for corporate network (auto-added by test runner)
export HTTP_PROXY="$VM_PROXY_URL"
export HTTPS_PROXY="$VM_PROXY_URL"
export http_proxy="$VM_PROXY_URL"
export https_proxy="$VM_PROXY_URL"
export ALL_PROXY="$VM_PROXY_URL"
export NO_PROXY="localhost,127.0.0.1,192.168.64.0/24"
PROXYEOF
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "cat >> ~/.bash_profile" << PROXYEOF
# Proxy configuration for corporate network (auto-added by test runner)
export HTTP_PROXY="$VM_PROXY_URL"
export HTTPS_PROXY="$VM_PROXY_URL"
export http_proxy="$VM_PROXY_URL"
export https_proxy="$VM_PROXY_URL"
export ALL_PROXY="$VM_PROXY_URL"
export NO_PROXY="localhost,127.0.0.1,192.168.64.0/24"
PROXYEOF
fi

# Set default shell if specified
if [[ -n "$SHELL_TYPE" ]]; then
    echo "Setting default shell to: $SHELL_TYPE"
    case "$SHELL_TYPE" in
        bash)
            sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "sudo chsh -s /bin/bash $VM_USER"
            ;;
        zsh)
            sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP" "sudo chsh -s /bin/zsh $VM_USER"
            ;;
    esac
fi

# Copy dotfiles to VM
echo "Copying dotfiles to VM..."
sshpass -p "$VM_PASS" scp -o StrictHostKeyChecking=no -r "$DOTFILES_ROOT" "$VM_USER@$VM_IP:~/.darwin_dotfiles"

echo ""
echo "========================================"
echo "VM Ready!"
echo "========================================"
echo ""
echo "Configuration applied:"
echo "  ✓ DNS: 8.8.8.8, 8.8.4.4"
if security find-certificate -a -c "Zscaler" -p /Library/Keychains/System.keychain >/dev/null 2>&1; then
    echo "  ✓ SSL: Zscaler certificate installed"
fi
if [[ -n "$VM_PROXY_URL" ]]; then
    echo "  ✓ Proxy: $VM_PROXY_URL"
fi
echo "  ✓ Dotfiles copied to ~/.darwin_dotfiles"
echo ""
echo "Quick start commands (run inside VM):"
echo "  ~/.darwin_dotfiles/setup/init.sh    # Initialize dotfiles"
echo "  install_devtools -v                  # Install dev tools"
echo ""
echo "Connecting via SSH..."
echo "(Type 'exit' to disconnect, VM will keep running)"
echo ""

# SSH into VM
sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$VM_IP"

# After SSH session ends
echo ""
echo "SSH session ended."
echo ""
echo "VM is still running. Options:"
echo "  ./test/run-interactive-vm.sh --ssh   # Reconnect"
echo "  pkill -f 'tart run $VM_NAME'         # Stop VM"
echo "  tart delete $VM_NAME                 # Delete VM"
echo ""

