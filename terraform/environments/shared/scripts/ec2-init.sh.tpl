#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
echo "### [START] UserData Script - $(date)"

# 1. 시스템 패키지 업데이트
yum update -y

# 2. deploy 사용자 생성 (비밀번호 없이, 홈 디렉토리 포함)
if ! id deploy &>/dev/null; then
  useradd -m deploy
fi

mkdir -p /home/deploy/.ssh
chmod 700 /home/deploy/.ssh

# 기본 사용자의 authorized_keys 파일 복사
cp /home/ec2-user/.ssh/authorized_keys /home/deploy/.ssh/
chmod 600 /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh

# 3. Docker 설치 (Amazon Linux 2023는 dnf 사용)
if ! command -v docker >/dev/null 2>&1; then
  dnf install -y docker
fi

systemctl enable docker
systemctl start docker

# 4. Docker 설치 후 deploy 사용자를 docker 그룹에 추가
getent group docker || groupadd docker
usermod -aG docker deploy

# 5. CodeDeploy Agent 설치
if ! systemctl is-active --quiet codedeploy-agent; then
  yum install -y ruby wget
  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  cd /home/deploy || cd /tmp
  wget "https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
  chmod +x ./install
  ./install auto
  systemctl enable codedeploy-agent
  systemctl start codedeploy-agent
fi

# 6. (옵션) Docker Compose v2 설치
if ! command -v docker-compose >/dev/null 2>&1; then
  DOCKER_COMPOSE_VERSION="2.29.2"
  curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true
fi

echo "### [COMPLETE] UserData Script - $(date)"