#!/bin/bash
set -e

# 로그 기록
exec > >(tee -a /var/log/base-init.log) 2>&1

echo "========== 기본 초기화 시작 =========="

# deploy 사용자 생성 및 SSH 키 등록
if id "deploy" &>/dev/null; then
  echo "[INFO] deploy 사용자 이미 존재함"
else
  echo "[INFO] deploy 사용자 생성 및 SSH 키 등록"
  useradd -m -s /bin/bash deploy
  mkdir -p /home/deploy/.ssh
  echo "${deploy_ssh_public_key}" > /home/deploy/.ssh/authorized_keys
  chmod 700 /home/deploy/.ssh
  chmod 600 /home/deploy/.ssh/authorized_keys
  chown -R deploy:deploy /home/deploy/.ssh
fi

# deploy 사용자에 제한 sudo 권한 부여 (docker / openvpnas 제어용)
if ! grep -q "deploy" /etc/sudoers; then
  echo "deploy ALL=(ALL) NOPASSWD: /bin/systemctl * docker, /bin/systemctl * openvpnas, /bin/service openvpnas *" >> /etc/sudoers
fi

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