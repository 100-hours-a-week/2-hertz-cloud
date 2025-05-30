
#!/bin/bash
set -e

# 로그 설정
exec > >(tee /var/log/user-data.log) 2>&1
echo "======================================================"
echo "OpenVPN Access Server 설치 시작: $(date)"
echo "======================================================"

# Docker 설치 (공식 스크립트 사용)
echo "[INFO] Docker 설치 중..."
curl -fsSL https://get.docker.com -o get-docker.sh
chmod +x get-docker.sh
sh get-docker.sh
rm -f get-docker.sh

# deploy 사용자에 docker 그룹 권한 부여
usermod -aG docker deploy

# AWS CLI 설치
echo "[INFO] AWS CLI 설치 중..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "[INFO] 기본 초기화 완료"