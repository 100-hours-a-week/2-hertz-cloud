#!/bin/bash
set -e

# 로그 기록
exec > >(tee -a /var/log/base-init.log) 2>&1

echo "========== 기본 초기화 시작 =========="

# SSH 서버 설치 및 활성화
echo "[INFO] SSH 서버 설치 중..."
apt-get update -y
apt-get install -y openssh-server
systemctl enable ssh
systemctl restart ssh

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

# (선택) deploy에 제한 sudo 권한 부여
if ! grep -q "deploy" /etc/sudoers; then
  echo "deploy ALL=(ALL) NOPASSWD: /bin/systemctl * docker, /bin/systemctl * openvpnas, /bin/service openvpnas *" >> /etc/sudoers
fi

# Docker 설치
echo "[INFO] Docker 설치 중..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl restart docker

# AWS CLI 설치
echo "[INFO] AWS CLI 설치 중..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
apt-get install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

echo "[INFO] 기본 초기화 완료"
