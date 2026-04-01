#!/bin/bash

# --- 配置区域 ---
# 在这里配置多个目录，用空格隔开
LOG_DIRS="/var/lib/cloudflare-warp/logs /logs"

INTERVAL=86400       # 24小时
RETAIN_BYTES=1048576 # 1MB (1024 * 1024)
MAX_DEPTH=5          # 查找深度
# ------------------

echo "守护进程已启动 (PID: $$)"

# 守护进程死循环
while true; do
    # 1. 等待指定时间
    sleep $INTERVAL

    # 2. 遍历配置的每一个目录
    for LOG_DIR in $LOG_DIRS; do
        # 检查目录是否存在，不存在则跳过
        if [ ! -d "$LOG_DIR" ]; then
            continue
        fi

        # 查找并清理文件
        # 使用进程替换 < <(...) 避免子Shell变量作用域问题
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                # 获取文件大小 (静默执行)
                current_size=$(sudo -u warpuser stat -c%s "$file" 2>/dev/null)

                # 如果大于设定值，则截断
                if [ "$current_size" -gt "$RETAIN_BYTES" ]; then
                    # 核心清理逻辑
                    sudo -u warpuser sh -c "tail -c $RETAIN_BYTES '$file' > '${file}.tmp' && mv '${file}.tmp' '$file'"
                fi
            fi
        done < <(sudo -u warpuser find "$LOG_DIR" -maxdepth $MAX_DEPTH -type f \( -name "*.log" -o -name "*.txt" \))
    done
done