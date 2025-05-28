#!/bin/bash
set -e

# 로그 설정
exec > >(tee /var/log/user-data.log) 2>&1
echo "======================================================"
echo "OpenVPN Access Server 설치 시작: $(date)"
echo "======================================================"

# 사용자 비밀번호 주입 (Terraform에서 templatefile로 전달)
CUSTOM_PASSWORD="${openvpn_admin_password}"
if [ -z "$CUSTOM_PASSWORD" ]; then
  echo "[ERROR] 관리자 비밀번호가 설정되지 않았습니다. 종료합니다."
  exit 1
fi
echo "[INFO] 설정할 관리자 비밀번호: $CUSTOM_PASSWORD"

# 설치 전 필수 패키지
sudo apt-get update -y
sudo apt-get install -y curl wget net-tools expect

# OpenVPN Access Server 다운로드 및 설치
sudo wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repository.asc
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/as-repository.asc] http://as-repository.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
sudo apt update && sudo apt -y install openvpn-as

# 서버 IP 추출
SERVER_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
echo "[INFO] Public IP: $SERVER_IP"

# OpenVPN 초기화 자동화 expect 스크립트 생성
sudo tee /root/auto-ovpn-init.expect > /dev/null <<EOF
#!/usr/bin/expect -f

set timeout -1
set password "\$env(CUSTOM_PASSWORD)"
set activation_key ""

sudo /usr/local/openvpn_as/bin/ovpn-init --batch
# 서비스 시작
sudo service openvpnas start

# 서비스가 완전히 뜰 때까지 대기
echo "OpenVPN 서비스가 시작될 때까지 대기 중..."
for i in {1..30}; do
    if sudo netstat -tnlp | grep -q ':943'; then
        echo "OpenVPN admin port opened!"
        break
    fi
    sleep 1
done

# 관리자 비밀번호 재설정 보장
sudo /usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$CUSTOM_PASSWORD" SetLocalPassword

# 외부 IP 또는 FQDN으로 설정
sudo /usr/local/openvpn_as/scripts/sacli --key "vpn.server.host" \
                                   --value "$SERVER_IP" \
                                   ConfigPut

# 설정 적용 및 서버 업데이트
sudo /usr/local/openvpn_as/scripts/sacli ConfigQuery
sudo /usr/local/openvpn_as/scripts/sacli ConfigPush

# 서비스 재시작
sudo service openvpnas restart

# 정보 저장
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

# 커널 포워딩 설정
echo "시스템 최적화 설정 적용 중..."
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo "[INFO] 설치 완료. 접속: https://$SERVER_IP:943/admin"