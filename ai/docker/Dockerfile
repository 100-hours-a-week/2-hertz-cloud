
# 속도 최우선: full python 이미지 사용
FROM python:3.10

WORKDIR /app

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    PORT=8000 \
    OMP_NUM_THREADS=1 \
    MKL_NUM_THREADS=1 \
    NUMEXPR_NUM_THREADS=1 \
    OPENBLAS_NUM_THREADS=1 \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 

# 필수 패키지만 빠르게 설치 (소스 빌드 없음)
RUN apt-get update && apt-get install -y \
    sqlite3 libsqlite3-dev libjemalloc-dev


# requirements 복사 및 설치 (PIP 캐시 사용 → 속도 빠름)
# requirements 복사 및 설치
COPY requirements.txt ./
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt
   

# 앱 복사 (마지막에)
COPY app ./app

EXPOSE 8000

CMD ["sh", "-c", "uvicorn app.main:app \
  --host 0.0.0.0 \
  --port 8000 \
  --workers ${UVICORN_WORKERS:-1} \
  --log-level info"]