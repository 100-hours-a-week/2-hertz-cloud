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



sudo apt-get install -y curl wget net-tools expect

# OpenVPN Access Server 다운로드 및 설치
sudo wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repository.asc
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/as-repository.asc] http://as-repository.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
sudo apt -y install openvpn-as


# OpenVPN 초기화 자동화 expect 스크립트 생성
sudo tee /root/auto-ovpn-init.expect > /dev/null << 'EOF'
#!/usr/bin/expect -f

set timeout -1
set password "$env(CUSTOM_PASSWORD)"
set activation_key ""

spawn sudo /usr/local/openvpn_as/bin/ovpn-init

expect {
    "Please enter 'DELETE' to delete existing configuration" {
        send "DELETE\r"
        exp_continue
    }
    "indicate your agreement" {
        send "yes\r"
    }
}

expect "Press ENTER for default"               { send "\r" }
expect "Please enter the option number*"       { send "1\r" }
expect "Press ENTER for default [secp384r1]:"  { send "\r" }
expect "Press ENTER for default [secp384r1]:"  { send "\r" }
expect "Press ENTER for default [943]:"        { send "\r" }   ;# 여기에서 1443 포트로 변경
expect "Press ENTER for default [443]:"        { send "\r" }   ;# 여기에서 2443 포트로 변경
expect "Press ENTER for default [yes]:"        { send "yes\r" }    ;# 여기서는 yes 입력 (예시)
expect "Press ENTER for default [yes]:"        { send "no\r" }     ;# 여기에서 no 입력 (예시)
expect "Press ENTER for default [yes]:"        { send "yes\r" }    ;# 여기서는 yes 입력 (예시)
expect "Press ENTER for default [yes]:"        { send "\r" }       ;# 기본값(Enter) 유지
expect "Do you wish to login to the Admin UI as \"openvpn\"?" { send "\r" }
expect "Type a password for the 'openvpn' account"          { send "$password\r" }
expect "Confirm the password for the 'openvpn' account:"    { send "$password\r" }
expect "specify your Activation key"                        { send "$activation_key\r" }


expect eof
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