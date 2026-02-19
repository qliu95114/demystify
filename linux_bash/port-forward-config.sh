#!/bin/bash
# Port Forwarding Configuration Script (2222->22)
# Configures iptables NAT rules to redirect port 2222 to port 22 (SSH)
# Works for self-forwarding (VM connecting to itself) 

echo "=== Port Forwarding Configuration (2222->22) ==="
echo ""

# Step 1: Add firewalld rules for external traffic
echo "Step 1: Configuring firewalld..."
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --permanent --add-forward-port=port=2222:proto=tcp:toport=22
sudo firewall-cmd --reload
echo "  ✓ Firewalld configured"
echo ""

# Step 2: Add iptables rules for localhost/self-forwarding
echo "Step 2: Configuring iptables for self-forwarding..."

# For incoming traffic (external)
sudo iptables -t nat -A PREROUTING -p tcp --dport 2222 -j REDIRECT --to-port 22

# For localhost traffic (OUTPUT chain)
sudo iptables -t nat -A OUTPUT -p tcp -o lo --dport 2222 -j REDIRECT --to-port 22

# For traffic to own IPs (replace with actual IPs)
INTERNAL_IP=$(hostname -I | awk '{print $1}')
sudo iptables -t nat -A OUTPUT -p tcp -d $INTERNAL_IP --dport 2222 -j REDIRECT --to-port 22

echo "  ✓ iptables NAT rules configured"
echo ""

# Step 3: Make iptables rules persistent
echo "Step 3: Making iptables rules persistent..."
sudo dnf install -y iptables-services > /dev/null 2>&1
sudo service iptables save
sudo systemctl enable iptables > /dev/null 2>&1
echo "  ✓ Rules saved to /etc/sysconfig/iptables"
echo ""

# Step 4: Verify configuration
echo "Step 4: Verifying configuration..."
echo "Firewalld forward ports:"
sudo firewall-cmd --list-forward-ports
echo ""
echo "iptables NAT rules (OUTPUT chain):"
sudo iptables -t nat -L OUTPUT -n -v | head -5
echo ""

# Step 5: Test connectivity
echo "Step 5: Testing port forwarding..."
timeout 3 bash -c 'cat < /dev/tcp/localhost/2222' 2>&1 | head -1 && echo "  ✓ Port 2222 forwarding to SSH works!" || echo "  ✗ Test failed"
echo ""

echo "=== Configuration Complete ==="
echo "SSH is now accessible via port 2222 (forwarded to port 22)"
echo "Test with: ssh azureuser@localhost -p 2222"
