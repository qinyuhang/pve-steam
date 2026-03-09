# 使用 Debian 作为基础镜像（与 PVE 相同）
FROM debian:bookworm-slim

# 安装必要的依赖：Go、git、ca-certificates
RUN apt-get update && apt-get install -y \
    golang-go \
    git \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制 go.mod 和源代码
COPY go.mod main.go ./

# 下载依赖
RUN go mod tidy

# 构建二进制文件
RUN go build -o steamvmctl main.go

# 暴露默认端口
EXPOSE 8080

# 设置环境变量（实际运行时通过 -e 传入）
ENV VMID="" \
    TOKEN="" \
    PORT="8080"

# 启动命令
ENTRYPOINT ["./steamvmctl"]
