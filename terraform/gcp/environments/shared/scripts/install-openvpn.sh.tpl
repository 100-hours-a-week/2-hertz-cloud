#!/bin/bash
set -e

# 로그 설정
exec > >(tee /var/log/user-data.log) 2>&1
echo "======================================================"
echo "OpenVPN Access Server 설치 시작: $(date)"
echo "======================================================"

# 사용자 비밀번호 주입 (Terraform에서 templatefile로 전달)
CUSTOM_PASSWORD="${admin_password}"
if [ -z "$CUSTOM_PASSWORD" ]; then
  echo "[ERROR] 관리자 비밀번호가 설정되지 않았습니다. 종료합니다."
  exit 1
fi
echo "[INFO] 설정할 관리자 비밀번호: $CUSTOM_PASSWORD"

# 설치 전 필수 패키지
apt-get update -y
apt-get install -y curl wget net-tools

# OpenVPN Access Server 다운로드 및 설치
wget https://openvpn.net/downloads/openvpn-as-latest-ubuntu22.amd64.deb -O openvpn-as.deb
dpkg -i openvpn-as.deb || apt-get install -f -y

# 서버 IP 추출
SERVER_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
echo "[INFO] Public IP: $SERVER_IP"

# 관리자 비밀번호 설정
/usr/local/openvpn_as/scripts/sacli --user openvpn --new_pass "$CUSTOM_PASSWORD" SetLocalPassword

# 서비스 시작
service openvpnas restart

# 정보 저장
cat <<EOF > /root/openvpn-info.txt
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

chmod 600 /root/openvpn-info.txt

echo "[INFO] 설치 완료. 접속: https://$SERVER_IP:943/admin"