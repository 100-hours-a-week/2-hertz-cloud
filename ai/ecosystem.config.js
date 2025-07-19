//tuning-api
module.exports = {
    apps: [
      {
        name: "fastapi-ai",
        script: "/home/deploy/venv/bin/python",
        args: "-m uvicorn main:app --host 0.0.0.0 --port 8000 --app-dir app-tuning",
        cwd: "/home/deploy/2-hertz-ai",
        env: {
          ENV: "dev",
          PYTHONIOENCODING: "utf-8",
          PYTHONPATH: "."
        },
        watch: false,
        restart_delay: 5000
      },
      {
        name: "chromadb",
        script: "/home/deploy/venv/bin/chroma",
        args: "run --port 8001 --path /home/deploy/chroma-data",
        interpreter: "none",
        exec_mode: "fork",
        env: {
          ENV: "prod"
        }
      }
    ]
  };

//GPU
module.exports = {
  apps: [
    {
            name: "vllm-server",
      script: "/home/deploy/2-hertz-ai/.venv/bin/python",
     // args: "serve wiseyoh/Midm-2.0-Base-Instruct-AWQ --port 8001 --enable-auto-tool-choice --tool-call-parser llama3_json",
      args: "-m vllm.entrypoints.openai.api_server --model wiseyoh/Midm-2.0-Base-Instruct-AWQ --port 8001 --enable-auto-tool-choice --tool-call-parser llama3_json ", // ← 모델 경로나 모델명 수정
      interpreter: "none",
      cwd: "/home/deploy/2-hertz-ai",
      env: {
        ENV: "prod",
        PYTHONIOENCODING: "utf-8",
      },
      out_file: "./logs/vllm.log",
      error_file: "./logs/vllm.log",
      log_date_format: "YYYY-MM-DD HH:mm:ss",
      watch: true,
      restart_delay: 5000
    },
    

{
  name: "tuning-report",
  script: "/home/deploy/2-hertz-ai/.venv/bin/python",
  args: "-m uvicorn app-report.main:app --host 0.0.0.0 --port 8000",
  interpreter: "none",
  cwd: "/home/deploy/2-hertz-ai",
  env: {
    ENV: "prod",
    PYTHONIOENCODING: "utf-8",
    PYTHONPATH: ".",
  },
  out_file: "./logs/fastapi-ai.log",
  error_file: "./logs/fastapi-ai.log",
  log_date_format: "YYYY-MM-DD HH:mm:ss",
  watch: true,
  restart_delay: 100,
  max_restarts: 5,
  autorestart: true,
  cron_restart: null,
  post_update: []
}
  ]
};