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

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
declare -a FAILED_TESTS

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
    FAILED_TESTS+=("$1")
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

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
    if tart list | grep -q "$vm_name"; then
        log_info "Deleting existing VM: $vm_name"
        tart delete "$vm_name" 2>/dev/null || true
    fi
    
    # Check if base image exists, pull if not
    if ! tart list | grep -q "dotfiles-base"; then
        log_info "Pulling base image: $BASE_IMAGE"
        tart clone "$BASE_IMAGE" dotfiles-base
    fi
    
    # Clone from local base for faster iteration
    tart clone dotfiles-base "$vm_name"
    
    echo "$vm_name"
}

# Start VM and wait for it to be ready
start_vm() {
    local vm_name="$1"
    
    log_info "Starting VM: $vm_name"
    
    # Start VM in background (headless)
    tart run "$vm_name" --no-graphics &
    VM_PID=$!
    
    log_info "Waiting for VM to boot (${BOOT_WAIT}s)..."
    sleep "$BOOT_WAIT"
    
    # Get VM IP
    local vm_ip
    vm_ip=$(tart ip "$vm_name" 2>/dev/null || echo "")
    
    if [[ -z "$vm_ip" ]]; then
        log_error "Failed to get VM IP address"
        return 1
    fi
    
    log_info "VM IP: $vm_ip"
    
    # Wait for SSH to be ready
    local timeout=$SSH_TIMEOUT
    while ! sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$VM_USER@$vm_ip" "echo ready" >/dev/null 2>&1; do
        ((timeout--))
        if [[ $timeout -le 0 ]]; then
            log_error "SSH timeout waiting for VM"
            return 1
        fi
        sleep 1
    done
    
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
    
    # Test PATH includes dotfiles bin
    local path_output
    path_output=$(vm_exec "$vm_ip" "source ~/.${shell_type}_profile 2>/dev/null; echo \$PATH")
    
    if [[ "$path_output" == *"darwin_dotfiles/bin"* ]]; then
        log_success "PATH includes dotfiles bin directory"
    else
        log_error "PATH does not include dotfiles bin directory"
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
    
    # Test git aliases
    for alias in ga gb gc gs gp; do
        if vm_exec "$vm_ip" "$source_cmd; type $alias" >/dev/null 2>&1; then
            log_success "Git alias '$alias' is available"
        else
            log_error "Git alias '$alias' not available"
        fi
    done
    
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

