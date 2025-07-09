# EKS 모니터링 스택 구성

## 구성 요소
- **Prometheus**: 메트릭 수집 및 저장
- **Grafana**: 시각화 대시보드
- **Loki**: 로그 수집 및 저장
- **Promtail**: 로그 수집 에이전트
- **Node Exporter**: 노드 메트릭 수집

## 설치 방법

### 1. 스크립트 실행
```bash
./monitoring-setup.sh
```

### 2. ArgoCD를 통한 배포
```bash
# ArgoCD 업그레이드 (모니터링 앱 포함)
helm upgrade --install argocd k8s-argocd-helm/argocd -f k8s-argocd-helm/values.yaml

# 또는 전체 스택 배포
helm upgrade --install hertz-cloud k8s-argocd-helm -f k8s-argocd-helm/values.yaml
```

## 접속 정보

### Grafana
```bash
# LoadBalancer IP 확인
kubectl get svc -n monitoring prometheus-stack-grafana

# 포트 포워딩 (선택사항)
kubectl port-forward -n monitoring svc/prometheus-stack-grafana 3000:80
```
- URL: http://localhost:3000 (포트 포워딩 시)
- Username: admin
- Password: admin123

### Prometheus
```bash
kubectl port-forward -n monitoring svc/prometheus-stack-kube-prom-prometheus 9090:9090
```
- URL: http://localhost:9090

## 모니터링 대상
- EKS 클러스터 리소스 (CPU, Memory, Network)
- 애플리케이션 메트릭 (Spring Boot Actuator)
- 시스템 로그 및 애플리케이션 로그
- Kubernetes 이벤트

## 주요 메트릭
- `node_cpu_seconds_total`: CPU 사용률
- `node_memory_MemAvailable_bytes`: 메모리 사용률
- `container_cpu_usage_seconds_total`: 컨테이너 CPU
- `container_memory_usage_bytes`: 컨테이너 메모리

## 유용한 명령어
```bash
# 모니터링 파드 상태 확인
kubectl get pods -n monitoring

# 서비스 확인
kubectl get svc -n monitoring

# 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana
```