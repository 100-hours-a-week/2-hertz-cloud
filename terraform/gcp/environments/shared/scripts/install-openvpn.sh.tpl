#!/bin/bash
set -e

exec > >(tee /var/log/user-data.log) 2>&1
echo "======================================================"
echo "OpenVPN Access Server install started: $(date)"
echo "======================================================"

CUSTOM_PASSWORD="${openvpn_admin_password}"
if [ -z "$CUSTOM_PASSWORD" ]; then
  echo "[ERROR] Admin password not set. Exiting."
  exit 1
fi
echo "[INFO] Admin password configured"

echo "[INFO] Getting server IP from GCP metadata..."
SERVER_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
echo "[INFO] External IP: $SERVER_IP"
echo "[INFO] Internal IP: $INTERNAL_IP"

sudo apt-get update -y
sudo apt-get install -y curl wget net-tools expect

echo "[INFO] Adding OpenVPN repository..."
sudo wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repository.asc
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/as-repository.asc] http://as-repository.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
sudo apt update && sudo apt -y install openvpn-as

echo "[INFO] Creating OpenVPN initialization script..."
sudo tee /root/auto-ovpn-init.expect > /dev/null << 'EXPECTSCRIPT'
#!/usr/bin/expect -f



spawn sudo /usr/local/openvpn_as/bin/ovpn-init

sudo tee /root/auto-ovpn-init.expect > /dev/null << 'EOF'
#!/usr/bin/expect -f
set activation_key ""
# 디버그 모드 활성화 (문제 해결용)
# exp_internal 1
spawn sudo /usr/local/openvpn_as/bin/ovpn-init
# 기존 설정 삭제 여부 (필요시)


expect {
    "Please enter 'DELETE' to delete existing configuration" {
        send "DELETE\r"
        exp_continue
    }
    "indicate your agreement" {
        send "yes\r"
    }
}
# Primary Access Server 노드 설정
expect {
    -re "Press ENTER for default.*yes.*:" {
        send "\r"
    }
}
# 네트워크 인터페이스 선택
expect {
    -re "Please enter the option number.*>" {
        send "1\r"
    }
}
# OpenVPN CA 암호화 알고리즘
expect {
    -re "Press ENTER for default.*secp384r1.*:" {
        send "\r"
    }
}
# 웹 인증서 암호화 알고리즘
expect {
    -re "Press ENTER for default.*secp384r1.*:" {
        send "\r"
    }
}
# Admin Web UI 포트
expect {
    -re "Press ENTER for default.*943.*:" {
        send "\r"
    }
}
# OpenVPN Daemon TCP 포트
expect {
    -re "Press ENTER for default.*443.*:" {
        send "\r"
    }
}
# 클라이언트 트래픽 VPN 라우팅 - NO 답변
expect "Should client traffic be routed by default through the VPN?"
expect {
    -re "Press ENTER for default.*yes.*:" {
        send "no\r"
    }
}
# DNS 트래픽 VPN 라우팅 - NO 답변
expect "Should client DNS traffic be routed by default through the VPN?"
expect {
    -re "Press ENTER for default.*yes.*:" {
        send "no\r"
    }
}
# Private 서브넷 접근 허용
expect {
    "Should private subnets be accessible to clients by default?" {
        expect -re "Press ENTER for default.*yes.*:"
        send "\r"
    }
}
# Admin UI 로그인 계정 설정
expect {
    "Do you wish to login to the Admin UI as \"openvpn\"?" {
        expect -re "Press ENTER for default.*yes.*:"
        send "\r"
    }
}
# 🔧 패스워드 설정 부분 수정
expect {
    -re "Type a password.*if left blank.*:" {
        send "\r"
    }
    -re "Type a password.*:" {
        send "\r"
    }
}
# 🔧 패스워드 확인 부분 수정
expect {
    -re "Confirm.*password.*:" {
        send  "\r"
    }
    -re ".*Confirm.*:" {
        send  "\r"
    }
}
# Activation Key 처리
expect {
    -re "specify your Activation key.*:" {
        if {$activation_key eq ""} {
            send "\r"
        } else {
            send "$activation_key\r"
        }
    }
    -re "Activation key.*:" {
        if {$activation_key eq ""} {
            send "\r"
        } else {
            send "$activation_key\r"
        }
    }
}
# 설정 완료 대기
expect {
    -re "successfully installed" {
        puts "\n=== OpenVPN Access Server 설치 완료! ==="
    }
    -re "configuration complete" {
        puts "\n=== 설정 완료! ==="
    }
    eof {
        puts "\n=== 설정 프로세스 종료 ==="
    }
}
EOF

sudo chmod +x /root/auto-ovpn-init.expect
echo "[INFO] Running OpenVPN initialization..."
sudo /root/auto-ovpn-init.expect

echo "[INFO] Starting OpenVPN service..."
sudo service openvpnas start

echo "[INFO] Waiting for service to be ready..."
for i in {1..30}; do
    if sudo netstat -tnlp | grep -q ':943'; then
        echo "[INFO] OpenVPN admin port is ready"
        break
    fi
    sleep 1
done

echo "[INFO] Setting admin password..."
sudo /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$CUSTOM_PASSWORD" SetLocalPassword

echo "[INFO] Configuring external IP settings..."
sudo tee /root/fix-openvpn-ip.sh > /dev/null << 'IPFIXSCRIPT'
#!/bin/bash
EXTERNAL_IP=$(curl -s ifconfig.me)
echo "[INFO] Setting external IP: $EXTERNAL_IP"

sudo /usr/local/openvpn_as/scripts/sacli --key "host.name" --value "$EXTERNAL_IP" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.daemon.0.listen.ip" --value "all" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "admin_ui.https.ip_address" --value "all" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "cs.https.ip_address" --value "all" ConfigPut

sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.reroute_gw" --value "false" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.reroute_dns" --value "false" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_gw" --value "false" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.client.routing.reroute_dns" --value "false" ConfigPut

sudo ufw allow 1194/udp 2>/dev/null || true
sudo ufw allow 943/tcp 2>/dev/null || true

sudo /usr/local/openvpn_as/scripts/sacli start
echo "[INFO] External IP configuration completed"
IPFIXSCRIPT

sudo chmod +x /root/fix-openvpn-ip.sh
sudo /root/fix-openvpn-ip.sh

echo "[INFO] Configuring VPN private networks..."
VPN_PRIVATE_NETWORKS="${vpn_private_networks}"
if [ -n "$VPN_PRIVATE_NETWORKS" ]; then
    echo "[INFO] Setting private networks: $VPN_PRIVATE_NETWORKS"
    IFS=',' read -ra SUBNETS <<< "$VPN_PRIVATE_NETWORKS"
    
    for i in "$${!SUBNETS[@]}"; do
        CIDR="$${SUBNETS[$${i}]}"
        if [[ -n "$CIDR" ]]; then
            echo "[INFO] Adding network: $CIDR"
            sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.routing.private_network.$${i}" --value "$CIDR" ConfigPut
        fi
    done
fi

echo "[INFO] Restarting OpenVPN service..."
sudo service openvpnas restart

echo "[INFO] Saving connection information..."
sudo tee /root/openvpn-info.txt > /dev/null << INFOFILE
OpenVPN Access Server Information

Admin UI: https://$SERVER_IP:943/admin
Client UI: https://$SERVER_IP:943/
Username: openvpn
Password: $CUSTOM_PASSWORD

External IP: $SERVER_IP
Internal IP: $INTERNAL_IP

VPN Port: UDP 1194
Web Ports: TCP 443 (Client), TCP 943 (Admin)

Installation completed: $(date)
INFOFILE

sudo chmod 600 /root/openvpn-info.txt

echo "[INFO] Enabling IP forwarding..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "======================================================"
echo "[SUCCESS] OpenVPN installation completed!"
echo "Admin UI: https://$SERVER_IP:943/admin"
echo "Username: openvpn"
echo "Password: $CUSTOM_PASSWORD"
echo "======================================================"