# 多阶段构建 Dockerfile
# 为什么使用多阶段构建？
# 1. 减小镜像大小：只包含运行时需要的文件
# 2. 安全性：不包含构建工具和源代码
# 3. 构建缓存：可以更好地利用 Docker 缓存

# ==================== 阶段 1: 构建阶段 ====================
FROM python:3.11-slim as builder

# 设置工作目录
WORKDIR /app

# 安装构建依赖
# 为什么需要 build-essential？
# 某些 Python 包（如 psycopg2）需要编译 C 扩展
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖到虚拟环境
# 为什么使用 --user？
# 1. 避免权限问题
# 2. 与系统 Python 包隔离
RUN pip install --no-cache-dir --user -r requirements.txt

# ==================== 阶段 2: 运行阶段 ====================
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 从构建阶段复制已安装的包
# 为什么只复制 .local？
# 只复制用户安装的包，不复制系统包
COPY --from=builder /root/.local /root/.local

# 复制应用代码
COPY . .

# 设置环境变量
# 为什么设置 PATH？
# 确保可以使用 pip 安装的包
ENV PATH=/root/.local/bin:$PATH

# 暴露端口
# 为什么暴露端口？
# 1. 文档化：明确服务使用的端口
# 2. 网络配置：Docker/Kubernetes 需要知道端口
EXPOSE 8001

# 健康检查
# 为什么需要健康检查？
# 1. Docker: docker inspect 可以看到健康状态
# 2. Kubernetes: 可以作为健康检查探针
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')" || exit 1

# 运行应用
# 为什么使用 CMD 而不是 ENTRYPOINT？
# CMD 可以被覆盖，更灵活
CMD ["python", "main.py"]

