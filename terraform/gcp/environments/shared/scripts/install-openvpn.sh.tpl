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
apt-get update -y
apt-get install -y curl wget net-tools

# OpenVPN Access Server 다운로드 및 설치
wget https://as-repository.openvpn.net/as-repo-public.asc -qO /etc/apt/trusted.gpg.d/as-repository.asc
echo "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/as-repository.asc] http://as-repository.openvpn.net/as/debian jammy main" | sudo tee /etc/apt/sources.list.d/openvpn-as-repo.list
 apt update && apt -y install openvpn-as


# 서버 IP 추출
SERVER_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
echo "[INFO] Public IP: $SERVER_IP"


echo "OpenVPN Access Server 배치 모드 초기화 시작..."
/usr/local/openvpn_as/bin/ovpn-init --batch \
--force \
--ec2 \
--local_auth=1 \
--no_start \
--host=$${SERVER_IP} \
--iface=eth0 \
--admin_user=openvpn \
--admin_pw="$${CUSTOM_PASSWORD}" \
--license_agreement=yes \
--verb=3 \
--ca_key_type=secp384r1 \
--web_key_type=secp384r1 \
--reroute_gw=1 \
--reroute_dns=0 \
--private_subnets=1 \
--vpn_tcp_port=443 \
--cs_priv_port=943 \
--cs_pub_port=943

echo "OpenVPN Access Server 배치 모드 초기화 완료"

# 서비스 시작
echo "OpenVPN 서비스 시작 중..."
service openvpnas start
# 서비스가 완전히 뜰 때까지 대기
echo "OpenVPN 서비스가 시작될 때까지 대기 중..."
for i in {1..30}; do
    if netstat -tnlp | grep -q ':943'; then
        echo "OpenVPN admin port opened!"
        break
    fi
    sleep 1
done



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