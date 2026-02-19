#!/bin/bash  
#
# sockperf Installation Script
# This script installs Mellanox sockperf network performance tool from source
# Tested on Rocky Linux 9
#

set -e  # Exit on error

echo "=== sockperf Installation Script ==="
echo "Starting installation at $(date)"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "Please do not run as root. This script will use sudo when needed."
   exit 1
fi

# Install dependencies
echo "Step 1: Installing build dependencies..."
sudo dnf install -y git gcc gcc-c++ make autoconf automake libtool

# Clone sockperf repository
echo ""
echo "Step 2: Cloning sockperf repository from Mellanox..."
cd ~
if [ -d "sockperf" ]; then
    echo "Removing existing sockperf directory..."
    rm -rf sockperf
fi
git clone https://github.com/Mellanox/sockperf.git
cd sockperf

# Generate build configuration
echo ""
echo "Step 3: Generating build configuration..."
./autogen.sh

# Configure build
echo ""
echo "Step 4: Configuring build..."
./configure

# Build sockperf
echo ""
echo "Step 5: Building sockperf..."
make -j$(nproc)

# Install sockperf
echo ""
echo "Step 6: Installing sockperf to /usr/local/bin..."
sudo make install

# Verify installation
echo ""
echo "Step 7: Verifying installation..."
if command -v sockperf &> /dev/null; then
    echo "✓ sockperf installed successfully!"
    sockperf --version
else
    echo "✗ sockperf installation failed"
    exit 1
fi

echo ""
echo "=== Installation Complete ==="
echo "Location: $(which sockperf)"
echo ""
echo "Example usage:"
echo "  Server: sockperf server -i <ip> -p 11111"
echo "  Client: sockperf ping-pong -i <server_ip> -p 11111 -t 60"
echo ""
