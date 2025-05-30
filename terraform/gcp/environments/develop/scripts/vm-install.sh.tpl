
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

echo "[INFO] 기본 초기화 완료"

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


# ───────────────────────────────────────────────
# 2. ECR 로그인 (필요 시만)
# ───────────────────────────────────────────────
IMAGE = ${image}

if [[ "${use_ecr}" == "true" ]]; then
  echo "[startup] ECR 사용 설정 → 자격 증명 파일 작성 및 로그인"

  # 2-1) 자격 증명 파일 생성
  mkdir -p /root/.aws
  cat >/root/.aws/credentials <<EOF
[default]
AWS_ACCESS_KEY_ID=${aws_access_key_id}
AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
EOF

  # 2-2) 레지스트리 도메인 추출 → 로그인
  AWS_REGISTRY="$(echo "$IMAGE" | cut -d'/' -f1)"
  aws ecr get-login-password --region "$AWS_REGION" \
    | docker login --username AWS --password-stdin "$AWS_REGISTRY"
else
  echo "[startup] ECR 사용 안 함 → 로그인 스킵"
fi

# ───────────────────────────────────────────────
# 3. 기존 컨테이너 정리 & 새 이미지 배포
# ───────────────────────────────────────────────
docker rm -f app 2>/dev/null || true

echo "[startup] Pulling image $IMAGE"
docker pull "$IMAGE"

echo "[startup] Running container"
docker run -d --name app --restart always -p 8080:8080 "$IMAGE"

echo "[startup] $(date) — Completed"