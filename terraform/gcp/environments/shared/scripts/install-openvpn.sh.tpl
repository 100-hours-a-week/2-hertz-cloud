#!/bin/bash
set -e

# 로그 설정
exec > >(tee /var/log/user-data.log) 2>&1
echo "======================================================"
echo "OpenVPN Access Server 설치 시작: $(date)"
echo "======================================================"

CUSTOM_PASSWORD="${openvpn_admin_password}"
if [ -z "$CUSTOM_PASSWORD" ]; then
  echo "[ERROR] 관리자 비밀번호가 설정되지 않았습니다. 종료합니다."
  exit 1
fi
echo "[INFO] 설정할 관리자 비밀번호: $CUSTOM_PASSWORD"


# 서버 IP 추출
SERVER_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
echo "[INFO] Public IP: $SERVER_IP"


sudo apt-get update -y
sudo apt-get install -y curl wget net-tools expect

# OpenVPN Access Server 다운로드 및 설치
sudo wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repository.asc
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/as-repository.asc] http://as-repository.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
sudo apt update && sudo apt -y install openvpn-as


# OpenVPN 초기화 자동화 expect 스크립트 생성
sudo tee /root/auto-ovpn-init.expect > /dev/null << 'EOF'
#!/usr/bin/expect -f

set timeout -1
set password "$env(CUSTOM_PASSWORD)"
set activation_key ""

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

# Primary Access Server 노드 설정 (yes - 기본값)
expect {
    -re "Press ENTER for default.*yes.*:" {
        send "\r"
    }
}

# 네트워크 인터페이스 선택 (1 - 모든 인터페이스)
expect {
    -re "Please enter the option number.*1.*2.*>" {
        send "1\r"
    }
}

# OpenVPN CA 암호화 알고리즘 (secp384r1 - 기본값)
expect {
    -re "Press ENTER for default.*secp384r1.*:" {
        send "\r"
    }
}

# 웹 인증서 암호화 알고리즘 (secp384r1 - 기본값)
expect {
    -re "Press ENTER for default.*secp384r1.*:" {
        send "\r"
    }
}

# Admin Web UI 포트 (943 - 기본값)
expect {
    -re "Press ENTER for default.*943.*:" {
        send "\r"
    }
}

# OpenVPN Daemon TCP 포트 (443 - 기본값)
expect {
    -re "Press ENTER for default.*443.*:" {
        send "\r"
    }
}

# ⭐ 첫 번째 "no" 답변: 클라이언트 트래픽 VPN 라우팅
expect {
    "Should client traffic be routed by default through the VPN?" {
        expect -re "Press ENTER for default.*yes.*:"
        send "no\r"
    }
}

# ⭐ 두 번째 "no" 답변: 클라이언트 DNS 트래픽 VPN 라우팅
expect {
    "Should client DNS traffic be routed by default through the VPN?" {
        expect -re "Press ENTER for default.*yes.*:"
        send "no\r"
    }
}

# Private 서브넷 접근 허용 (yes - 기본값)
expect {
    "Should private subnets be accessible to clients by default?" {
        expect -re "Press ENTER for default.*yes.*:"
        send "\r"
    }
}

# Admin UI 로그인 계정 설정 (openvpn - 기본값)
expect {
    "Do you wish to login to the Admin UI as \"openvpn\"?" {
        expect -re "Press ENTER for default.*yes.*:"
        send "\r"
    }
}

# 패스워드 설정
expect {
    -re "Type a password for the 'openvpn' account.*:" {
        send "$password\r"
    }
}

# 패스워드 확인
expect {
    -re "Confirm password.*:" {
        send "$password\r"
    }
}

# Activation Key (비어있으면 엔터)
expect {
    -re "specify your Activation key.*:" {
        if {$activation_key eq ""} {
            send "\r"
        } else {
            send "$activation_key\r"
        }
    }
}

# 모든 설정 완료 대기
expect {
    -re "Access Server has been successfully installed" {
        puts "OpenVPN Access Server 설치 및 설정 완료!"
    }
    eof {
        puts "설정 프로세스 종료"
    }
    timeout {
        puts "설정 중 타임아웃 발생"
        exit 1
    }
}

EOF

sudo chmod +x /root/auto-ovpn-init.expect
sudo CUSTOM_PASSWORD="$CUSTOM_PASSWORD" /root/auto-ovpn-init.expect



# 2. 서비스 시작
sudo service openvpnas start

# 3. 서비스가 완전히 뜰 때까지 대기
echo "OpenVPN 서비스가 시작될 때까지 대기 중..."
for i in {1..30}; do
    if sudo netstat -tnlp | grep -q ':943'; then
        echo "OpenVPN admin port opened!"
        break
    fi
    sleep 1
done

# 4. 관리자 비밀번호 재설정 보장
sudo /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$CUSTOM_PASSWORD" SetLocalPassword

# 5. 외부 IP로 접속 설정
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.host" --value "$SERVER_IP" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.reroute_gw" --value "false" ConfigPut
sudo /usr/local/openvpn_as/scripts/sacli --user openvpn GetUserLogin > /home/deploy/openvpn-user.ovpn
# 6. 서비스 재시작
sudo service openvpnas restart

# 7. 정보 저장 (여기서 생성됨!)
sudo tee /root/openvpn-info.txt > /dev/null <<EOF
[OpenVPN Access Server 정보]

관리자 UI: https://$SERVER_IP:943/admin
클라이언트 UI: https://$SERVER_IP:943/
사용자: openvpn
비밀번호: $CUSTOM_PASSWORD

로그 위치:
  /var/log/openvpnas.log
  /usr/local/openvpn_as/log/openvpn.log

VPN 포트: UDP 1194
웹 포트: TCP 443 (Client), TCP 943 (Admin)
EOF

sudo chmod 600 /root/openvpn-info.txt

# 8. 커널 포워딩 설정
echo "시스템 최적화 설정 적용 중..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "[INFO] 설치 완료. 접속: https://$SERVER_IP:943/admin"