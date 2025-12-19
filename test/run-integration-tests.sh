#!/bin/bash

# Integration test runner for darwin_dotfiles
# Uses Tart to spin up clean macOS VMs and test installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_IMAGE="${TART_BASE_IMAGE:-ghcr.io/cirruslabs/macos-sequoia-base:latest}"
VM_NAME_PREFIX="dotfiles-test"
VM_USER="${VM_USER:-admin}"
VM_PASS="${VM_PASS:-admin}"
SSH_TIMEOUT=120
BOOT_WAIT=60

# Proxy configuration for Zscaler/corporate environments
VM_GATEWAY="192.168.64.1"
PROXY_FORWARD_PORT=9001
ZSCALER_PROXY_PORT=9000
PROXY_FORWARDER_PID=""

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" >&2
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_TESTS+=("$1")
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Start proxy forwarder for Zscaler environments
# Checks if Zscaler proxy is running on localhost and sets up a forwarder
# that the VM can reach
start_proxy_forwarder() {
    # Check if Zscaler proxy is listening on localhost
    if ! lsof -i :$ZSCALER_PROXY_PORT -sTCP:LISTEN >/dev/null 2>&1; then
        log_info "No local proxy on port $ZSCALER_PROXY_PORT, skipping proxy forwarder"
        return 0
    fi
    
    log_info "Detected Zscaler proxy on localhost:$ZSCALER_PROXY_PORT"
    log_info "Starting proxy forwarder ($VM_GATEWAY:$PROXY_FORWARD_PORT -> 127.0.0.1:$ZSCALER_PROXY_PORT)..."
    
    python3 "$SCRIPT_DIR/lib/proxy-forwarder.py" \
        "$VM_GATEWAY" "$PROXY_FORWARD_PORT" \
        "127.0.0.1" "$ZSCALER_PROXY_PORT" &
    PROXY_FORWARDER_PID=$!
    
    sleep 1
    
    if kill -0 $PROXY_FORWARDER_PID 2>/dev/null; then
        log_success "Proxy forwarder started (PID: $PROXY_FORWARDER_PID)"
        export VM_PROXY_URL="http://$VM_GATEWAY:$PROXY_FORWARD_PORT"
    else
        log_warn "Failed to start proxy forwarder"
        PROXY_FORWARDER_PID=""
    fi
}

# Stop proxy forwarder
stop_proxy_forwarder() {
    if [[ -n "$PROXY_FORWARDER_PID" ]]; then
        log_info "Stopping proxy forwarder..."
        kill $PROXY_FORWARDER_PID 2>/dev/null || true
        wait $PROXY_FORWARDER_PID 2>/dev/null || true
        PROXY_FORWARDER_PID=""
    fi
}

# Cleanup handler
cleanup() {
    stop_proxy_forwarder
    # Clean up any lingering test VMs
    for vm in $(tart list 2>/dev/null | grep "$VM_NAME_PREFIX" | awk '{print $2}'); do
        pkill -f "tart run $vm" 2>/dev/null || true
    done
}

trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v tart >/dev/null 2>&1; then
        log_error "Tart is not installed. Install with: brew install cirruslabs/cli/tart"
        exit 1
    fi
    
    if ! command -v sshpass >/dev/null 2>&1; then
        log_warn "sshpass not found. Installing..."
        brew install hudochenkov/sshpass/sshpass
    fi
    
    log_success "Prerequisites check passed"
}

# Create a fresh VM clone for testing
create_test_vm() {
    local shell_type="$1"
    local vm_name="${VM_NAME_PREFIX}-${shell_type}"
    
    log_info "Creating test VM: $vm_name"
    
    # Delete existing VM if present
    if tart list 2>/dev/null | grep -q "$vm_name"; then
        log_info "Deleting existing VM: $vm_name"
        tart delete "$vm_name" >/dev/null 2>&1 || true
    fi
    
    # Check if base image exists, pull if not
    if ! tart list 2>/dev/null | grep -q "dotfiles-base"; then
        log_warn "Base image 'dotfiles-base' not found."
        log_info "Pulling base image: $BASE_IMAGE"
        log_warn "This will download ~15GB and may take 10-30 minutes..."
        log_info "(Run ./test/setup-tart.sh first to do this step separately)"
        echo "" >&2
        tart clone "$BASE_IMAGE" dotfiles-base >&2
        echo "" >&2
        log_success "Base image pulled successfully"
    fi
    
    # Clone from local base for faster iteration
    tart clone dotfiles-base "$vm_name" >&2
    
    echo "$vm_name"
}

# Start VM and wait for it to be ready
start_vm() {
    local vm_name="$1"
    
    log_info "Starting VM: $vm_name"
    
    # Start VM in background (headless)
    tart run "$vm_name" --no-graphics >&2 &
    VM_PID=$!
    
    log_info "Waiting for VM to boot (${BOOT_WAIT}s)..."
    local i
    for ((i=BOOT_WAIT; i>0; i-=10)); do
        echo -ne "\r  ${BLUE}Boot wait:${NC} ${i}s remaining...  " >&2
        sleep 10
    done
    echo -e "\r  ${GREEN}Boot wait complete.${NC}              " >&2
    
    # Get VM IP
    local vm_ip
    vm_ip=$(tart ip "$vm_name" 2>/dev/null || echo "")
    
    if [[ -z "$vm_ip" ]]; then
        log_error "Failed to get VM IP address"
        return 1
    fi
    
    log_info "VM IP: $vm_ip"
    
    # Wait for SSH to be ready
    log_info "Waiting for SSH to be ready..."
    local timeout=$SSH_TIMEOUT
    while ! sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$VM_USER@$vm_ip" "echo ready" >/dev/null 2>&1; do
        timeout=$((timeout - 1))
        if [[ $timeout -le 0 ]]; then
            echo "" >&2
            log_error "SSH timeout waiting for VM"
            return 1
        fi
        if ((timeout % 10 == 0)); then
            echo -ne "\r  ${BLUE}SSH wait:${NC} ${timeout}s remaining...  " >&2
        fi
        sleep 1
    done
    echo -e "\r  ${GREEN}SSH connected.${NC}                    " >&2
    
    # Configure public DNS (VM may inherit unreachable corporate DNS from host)
    log_info "Configuring DNS..."
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$vm_ip" \
        "sudo networksetup -setdnsservers 'Ethernet' 8.8.8.8 8.8.4.4" >/dev/null 2>&1 || true
    
    # Install SSL proxy certificates (e.g., Zscaler) from host to VM
    # This handles corporate SSL inspection proxies
    if security find-certificate -a -c "Zscaler" -p /Library/Keychains/System.keychain >/dev/null 2>&1; then
        log_info "Installing Zscaler SSL certificate in VM..."
        local cert_file="/tmp/dotfiles-test-zscaler-ca.pem"
        security find-certificate -a -c "Zscaler" -p /Library/Keychains/System.keychain > "$cert_file" 2>/dev/null
        sshpass -p "$VM_PASS" scp -o StrictHostKeyChecking=no "$cert_file" "$VM_USER@$vm_ip:/tmp/" >/dev/null 2>&1
        sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$vm_ip" \
            "sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain /tmp/dotfiles-test-zscaler-ca.pem" >/dev/null 2>&1 || true
        rm -f "$cert_file"
    fi
    
    # Configure proxy environment if forwarder is running
    if [[ -n "$VM_PROXY_URL" ]]; then
        log_info "Configuring proxy environment in VM..."
        sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$vm_ip" "cat >> ~/.zprofile" << PROXYEOF
# Proxy configuration for corporate network (auto-added by test runner)
export HTTP_PROXY="$VM_PROXY_URL"
export HTTPS_PROXY="$VM_PROXY_URL"
export http_proxy="$VM_PROXY_URL"
export https_proxy="$VM_PROXY_URL"
export ALL_PROXY="$VM_PROXY_URL"
export NO_PROXY="localhost,127.0.0.1,192.168.64.0/24"
PROXYEOF
        sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$vm_ip" "cat >> ~/.bash_profile" << PROXYEOF
# Proxy configuration for corporate network (auto-added by test runner)
export HTTP_PROXY="$VM_PROXY_URL"
export HTTPS_PROXY="$VM_PROXY_URL"
export http_proxy="$VM_PROXY_URL"
export https_proxy="$VM_PROXY_URL"
export ALL_PROXY="$VM_PROXY_URL"
export NO_PROXY="localhost,127.0.0.1,192.168.64.0/24"
PROXYEOF
    fi
    
    log_success "VM is ready at $vm_ip"
    echo "$vm_ip"
}

# Execute command on VM via SSH
vm_exec() {
    local vm_ip="$1"
    shift
    local cmd="$*"
    
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no "$VM_USER@$vm_ip" "$cmd"
}

# Copy files to VM
vm_copy() {
    local vm_ip="$1"
    local source="$2"
    local dest="$3"
    
    sshpass -p "$VM_PASS" scp -o StrictHostKeyChecking=no -r "$source" "$VM_USER@$vm_ip:$dest"
}

# Change default shell on VM
set_default_shell() {
    local vm_ip="$1"
    local shell_type="$2"
    
    log_info "Setting default shell to: $shell_type"
    
    case "$shell_type" in
        bash)
            vm_exec "$vm_ip" "sudo chsh -s /bin/bash $VM_USER"
            ;;
        zsh)
            vm_exec "$vm_ip" "sudo chsh -s /bin/zsh $VM_USER"
            ;;
        *)
            log_error "Unknown shell type: $shell_type"
            return 1
            ;;
    esac
    
    log_success "Default shell set to $shell_type"
}

# Run installation tests
test_installation() {
    local vm_ip="$1"
    local shell_type="$2"
    
    log_info "=== Testing Installation ($shell_type) ==="
    
    # Copy dotfiles to VM (simulating fresh clone)
    log_info "Copying dotfiles to VM..."
    vm_exec "$vm_ip" "rm -rf ~/.darwin_dotfiles"
    vm_copy "$vm_ip" "$DOTFILES_ROOT" "~/.darwin_dotfiles"
    
    # Test init.sh
    log_info "Running init.sh..."
    if vm_exec "$vm_ip" "~/.darwin_dotfiles/setup/init.sh" >/dev/null 2>&1; then
        log_success "init.sh completed successfully"
    else
        log_error "init.sh failed"
        return 1
    fi
    
    # Verify profile files were created
    local profile_file
    if [[ "$shell_type" == "bash" ]]; then
        profile_file=".bash_profile"
    else
        profile_file=".zsh_profile"
    fi
    
    if vm_exec "$vm_ip" "test -f ~/$profile_file"; then
        log_success "Profile file created: ~/$profile_file"
    else
        log_error "Profile file not created: ~/$profile_file"
    fi
    
    # Verify managed section exists
    if vm_exec "$vm_ip" "grep -q 'DOTFILES MANAGED SECTION' ~/$profile_file"; then
        log_success "Managed section found in $profile_file"
    else
        log_error "Managed section not found in $profile_file"
    fi
}

# Run environment tests
test_environment() {
    local vm_ip="$1"
    local shell_type="$2"
    
    log_info "=== Testing Environment ($shell_type) ==="
    
    # Test DOTFILES_ROOT is set
    local dotfiles_root
    dotfiles_root=$(vm_exec "$vm_ip" "source ~/.${shell_type}_profile 2>/dev/null; echo \$DOTFILES_ROOT")
    
    if [[ "$dotfiles_root" == *".darwin_dotfiles"* ]]; then
        log_success "DOTFILES_ROOT is set correctly: $dotfiles_root"
    else
        log_error "DOTFILES_ROOT not set correctly: $dotfiles_root"
    fi
    
    # Test PATH includes dotfiles bin (only when FVM is installed)
    local path_output
    path_output=$(vm_exec "$vm_ip" "source ~/.${shell_type}_profile 2>/dev/null; echo \$PATH")
    local has_fvm
    has_fvm=$(vm_exec "$vm_ip" "command -v fvm >/dev/null 2>&1 && echo yes || echo no")
    
    if [[ "$has_fvm" == "yes" ]]; then
        if [[ "$path_output" == *"darwin_dotfiles/bin"* ]]; then
            log_success "PATH includes dotfiles bin directory (FVM installed)"
        else
            log_error "PATH does not include dotfiles bin directory (FVM is installed)"
        fi
    else
        log_info "Skipping PATH bin test (FVM not installed - bin only added with FVM)"
    fi
    
    # Test shell detection
    local is_bash
    is_bash=$(vm_exec "$vm_ip" "source ~/.${shell_type}_profile 2>/dev/null; source ~/.darwin_dotfiles/lib/core/dotfiles.sh; is_shell_bash && echo yes || echo no")
    
    if [[ "$shell_type" == "bash" && "$is_bash" == "yes" ]] || [[ "$shell_type" == "zsh" && "$is_bash" == "no" ]]; then
        log_success "Shell detection works correctly"
    else
        log_error "Shell detection incorrect (expected $shell_type, is_shell_bash returned $is_bash)"
    fi
}

# Run function tests
test_functions() {
    local vm_ip="$1"
    local shell_type="$2"
    
    log_info "=== Testing Functions ($shell_type) ==="
    
    # Create test profile source command
    local source_cmd="source ~/.${shell_type}_profile 2>/dev/null"
    
    # Test dotfiles_init is available
    if vm_exec "$vm_ip" "$source_cmd; type dotfiles_init" >/dev/null 2>&1; then
        log_success "dotfiles_init function is available"
    else
        log_error "dotfiles_init function not available"
    fi
    
    # Test 'up' function is available
    if vm_exec "$vm_ip" "$source_cmd; type up" >/dev/null 2>&1; then
        log_success "'up' function is available"
    else
        log_error "'up' function not available"
    fi
    
    # Test install_devtools is available
    if vm_exec "$vm_ip" "$source_cmd; type install_devtools" >/dev/null 2>&1; then
        log_success "install_devtools function is available"
    else
        log_error "install_devtools function not available"
    fi
}

# Run devtools installation test (optional, slower)
test_devtools() {
    local vm_ip="$1"
    local shell_type="$2"
    
    log_info "=== Testing DevTools Installation ($shell_type) ==="
    log_warn "This test installs Homebrew and may take several minutes..."
    
    local source_cmd="source ~/.${shell_type}_profile 2>/dev/null"
    
    # Run install_devtools
    log_info "Running install_devtools..."
    if vm_exec "$vm_ip" "$source_cmd; install_devtools -v" 2>&1; then
        log_success "install_devtools completed"
    else
        log_error "install_devtools failed"
        return 1
    fi
    
    # Verify Homebrew is installed
    if vm_exec "$vm_ip" "command -v brew" >/dev/null 2>&1; then
        log_success "Homebrew is installed"
    else
        log_error "Homebrew is not installed"
    fi
    
    # Verify jq is installed
    if vm_exec "$vm_ip" "command -v jq" >/dev/null 2>&1; then
        log_success "jq is installed"
    else
        log_error "jq is not installed"
    fi
    
    # Verify fvm is installed
    if vm_exec "$vm_ip" "command -v fvm" >/dev/null 2>&1; then
        log_success "FVM is installed"
    else
        log_warn "FVM is not installed (may be expected if Flutter already installed)"
    fi
}

# Cleanup VM
cleanup_vm() {
    local vm_name="$1"
    
    log_info "Cleaning up VM: $vm_name"
    
    # Kill VM process
    pkill -f "tart run $vm_name" 2>/dev/null || true
    
    # Wait a moment for process to terminate
    sleep 2
    
    # Delete VM
    tart delete "$vm_name" 2>/dev/null || true
    
    log_success "VM cleaned up: $vm_name"
}

# Run all tests for a shell type
run_tests_for_shell() {
    local shell_type="$1"
    local include_devtools="${2:-false}"
    
    log_info "========================================"
    log_info "Running tests for: $shell_type"
    log_info "========================================"
    
    local vm_name
    vm_name=$(create_test_vm "$shell_type")
    
    local vm_ip
    vm_ip=$(start_vm "$vm_name")
    
    if [[ -z "$vm_ip" ]]; then
        log_error "Failed to start VM"
        cleanup_vm "$vm_name"
        return 1
    fi
    
    # Set default shell
    set_default_shell "$vm_ip" "$shell_type"
    
    # Run tests
    test_installation "$vm_ip" "$shell_type"
    test_environment "$vm_ip" "$shell_type"
    test_functions "$vm_ip" "$shell_type"
    
    if [[ "$include_devtools" == "true" ]]; then
        test_devtools "$vm_ip" "$shell_type"
    fi
    
    # Cleanup
    cleanup_vm "$vm_name"
}

# Print test summary
print_summary() {
    echo ""
    echo "========================================"
    echo "TEST SUMMARY"
    echo "========================================"
    echo -e "${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "${RED}Failed:${NC} $TESTS_FAILED"
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo ""
        echo "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
    fi
    
    echo "========================================"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Main
main() {
    local shell_filter="${1:-all}"
    local include_devtools="${2:-false}"
    
    echo ""
    echo "========================================"
    echo "darwin_dotfiles Integration Tests"
    echo "========================================"
    echo ""
    
    check_prerequisites
    start_proxy_forwarder
    
    case "$shell_filter" in
        bash)
            run_tests_for_shell "bash" "$include_devtools"
            ;;
        zsh)
            run_tests_for_shell "zsh" "$include_devtools"
            ;;
        all)
            run_tests_for_shell "bash" "$include_devtools"
            run_tests_for_shell "zsh" "$include_devtools"
            ;;
        devtools)
            run_tests_for_shell "bash" "true"
            run_tests_for_shell "zsh" "true"
            ;;
        *)
            echo "Usage: $0 [bash|zsh|all|devtools]"
            echo ""
            echo "Options:"
            echo "  bash     - Test Bash shell only"
            echo "  zsh      - Test Zsh shell only"
            echo "  all      - Test both shells (default)"
            echo "  devtools - Test both shells + devtools installation"
            exit 1
            ;;
    esac
    
    print_summary
}

main "$@"

