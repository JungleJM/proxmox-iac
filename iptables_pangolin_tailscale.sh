#!/usr/bin/env bash
set -euo pipefail

# Interfaces
PUB_IF="eth0"
TAILSCALE_IF="tailscale0"

# Tailscale CGNAT range
TAILSCALE_NET="100.64.0.0/10"

echo "[*] Starting firewall apply with safety timer..."

# Safety timer: auto-reset to ACCEPT after 60s if not cancelled
(
  sleep 60
  echo "[!] Safety timer expired, resetting iptables to ACCEPT."
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -F
  iptables -t nat -F
  iptables -t mangle -F
) &

SAFETY_PID=$!

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Loopback
iptables -A INPUT -i lo -j ACCEPT

# Established/related
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow all traffic on Tailscale interface
iptables -A INPUT -i "$TAILSCALE_IF" -j ACCEPT

# SSH only from Tailscale IP range
iptables -A INPUT -p tcp --dport 22 -s "$TAILSCALE_NET" -j ACCEPT

# Pangolin HTTP/HTTPS on public interface
iptables -A INPUT -i "$PUB_IF" -p tcp --dport 80  -j ACCEPT
iptables -A INPUT -i "$PUB_IF" -p tcp --dport 443 -j ACCEPT

# Pangolin UDP ports on public interface
iptables -A INPUT -i "$PUB_IF" -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -i "$PUB_IF" -p udp --dport 21820 -j ACCEPT

echo "[*] Firewall rules applied."
echo "[*] Test SSH via Tailscale now. If everything works, run:"
echo "    kill $SAFETY_PID"
echo "    iptables-save > /etc/iptables/rules.v4"
echo "[*] If you do nothing, firewall will reset in 60 seconds."
