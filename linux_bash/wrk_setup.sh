#!/bin/bash
#
# wrk Installation Script
# This script installs wrk HTTP benchmarking tool from source
# Tested on Rocky Linux 9
#

set -e  # Exit on error

echo "=== wrk Installation Script ==="
echo "Starting installation at $(date)"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "Please do not run as root. This script will use sudo when needed."
   exit 1
fi

# Install dependencies
echo "Step 1: Installing build dependencies..."
sudo dnf install -y git gcc make openssl-devel unzip perl-core

# Clone wrk repository
echo ""
echo "Step 2: Cloning wrk repository..."
cd ~
if [ -d "wrk" ]; then
    echo "Removing existing wrk directory..."
    rm -rf wrk
fi
git clone https://github.com/wg/wrk.git
cd wrk

# Modify Makefile to use system OpenSSL
echo ""
echo "Step 3: Configuring build to use system OpenSSL..."
# Comment out the bundled OpenSSL paths in Makefile
sed -i 's/^\(LDFLAGS.*+=.*-L.*deps\/lib\)/#\1/' Makefile
sed -i 's/^\(CFLAGS.*+=.*-I.*deps\/include\)/#\1/' Makefile

# Build wrk
echo ""
echo "Step 4: Building wrk..."
make WITH_OPENSSL=/usr -j$(nproc)

# Install wrk
echo ""
echo "Step 5: Installing wrk to /usr/local/bin..."
sudo cp wrk /usr/local/bin/wrk
sudo chmod +x /usr/local/bin/wrk

# Verify installation
echo ""
echo "Step 6: Verifying installation..."
if command -v wrk &> /dev/null; then
    echo "✓ wrk installed successfully!"
    wrk --version
else
    echo "✗ wrk installation failed"
    exit 1
fi

echo ""
echo "=== Installation Complete ==="
echo "Location: $(which wrk)"
echo ""
echo "Example usage:"
echo "  wrk -t12 -c400 -d30s http://example.com"
echo ""
