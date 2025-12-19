#!/bin/bash

# Quick setup script for Tart integration testing environment
# This script helps you get started with testing darwin_dotfiles in macOS VMs

set -e

echo "========================================"
echo "Tart Integration Test Setup"
echo "========================================"
echo ""

# Check for Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    echo "⚠️  Warning: Tart works best on Apple Silicon (M1/M2/M3/M4) Macs."
    echo "   Intel Macs may have limited support."
    echo ""
fi

# Install Tart
if command -v tart >/dev/null 2>&1; then
    echo "✓ Tart is already installed: $(tart --version)"
else
    echo "Installing Tart..."
    brew install cirruslabs/cli/tart
    echo "✓ Tart installed"
fi

# Install sshpass (for automated SSH)
if command -v sshpass >/dev/null 2>&1; then
    echo "✓ sshpass is already installed"
else
    echo "Installing sshpass..."
    brew install hudochenkov/sshpass/sshpass
    echo "✓ sshpass installed"
fi

echo ""
echo "========================================"
echo "Pulling macOS Base Image"
echo "========================================"
echo ""
echo "This will download a ~15GB macOS VM image."
echo "The image is cached locally for future use."
echo ""

# Pull base image
if tart list 2>/dev/null | grep -q "dotfiles-base"; then
    echo "✓ Base image 'dotfiles-base' already exists"
    echo ""
    read -p "Do you want to update it? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        tart delete dotfiles-base
        tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest dotfiles-base
        echo "✓ Base image updated"
    fi
else
    echo "Pulling macOS Sequoia base image..."
    echo "(This may take 10-30 minutes depending on your connection)"
    echo ""
    tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest dotfiles-base
    echo ""
    echo "✓ Base image pulled successfully"
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Available commands:"
echo ""
echo "  # Run all integration tests (both Bash and Zsh)"
echo "  ./test/run-integration-tests.sh"
echo ""
echo "  # Run tests for a specific shell"
echo "  ./test/run-integration-tests.sh bash"
echo "  ./test/run-integration-tests.sh zsh"
echo ""
echo "  # Run tests including devtools (slower, installs Homebrew)"
echo "  ./test/run-integration-tests.sh devtools"
echo ""
echo "  # Interactive VM for manual testing"
echo "  ./test/run-interactive-vm.sh"
echo ""
echo "For more information, see test/README.md"
echo ""

