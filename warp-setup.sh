#!/bin/bash
set -e

# 等待WARP守护进程启动
echo "Waiting for WARP service to be ready"
sleep 5

# 检查配置文件, 判断是否已经注册并启动过了
echo "Checking if warp-svc is responding"

# 检查配置文件是否存在
if [ -s "/var/lib/cloudflare-warp/reg.json" ]; then
    echo "WARP configuration found. Ready to connect."
else

  echo "Setting warp mode"
  sudo -u warpuser warp-cli --accept-tos mode warp

  # registry warp (free/zero trust)
  if [ -z "$WARP_TOKEN" ]; then
      # 注册 free 账号
      sudo -u warpuser warp-cli --accept-tos registration new
      if [ -n "$WARP_LICENSE" ]; then
        echo "set WARP License..."
        sudo -u warpuser warp-cli registration license "$WARP_LICENSE"
      fi
  else
      # 注册 zero trust 账户
      TEAM_NAME=$(echo "$WARP_TOKEN" | grep -oP '(?<=//)[^/]+')
      TEAM_NAME=${TEAM_NAME%%.*}
      sudo -u warpuser warp-cli --accept-tos registration new "$TEAM_NAME"
      sudo -u warpuser warp-cli --accept-tos registration initialize-token-callback
      sudo -u warpuser warp-cli --accept-tos registration token "$WARP_TOKEN"
  fi

  # 检查注册状态
  echo "registration status"
  sudo -u warpuser warp-cli --accept-tos registration show
  # 连接warp
  echo "connect warp"
  sudo -u warpuser warp-cli --accept-tos connect

  # Loop to check if WARP is healthy
  RETRY_COUNT=0
  while true; do
      status=$(sudo -u warpuser warp-cli --accept-tos status)
      trace=$(curl -s --max-time 10 https://www.cloudflare.com/cdn-cgi/trace | grep warp)
        if [[ $status == *"healthy"* ]] && [[ -n "$trace" ]] && [[ ! $trace == *"off"* ]]; then
            echo "WARP is healthy and active (warp=on/plus)."
            echo "Trace info: $trace"
            break
        else
            echo "Condition not met. Retrying in 5 seconds..."
            echo "  CLI Status: $status"
            echo "  Trace Info: $trace"
            sleep 5
            ((RETRY_COUNT++))
            echo "health check $RETRY_COUNT times"
            if [[ $RETRY_COUNT == 50 ]]; then
              echo "health check 50 times, error connect..."
              break
            fi
        fi
  done
fi
echo "WARP setup completed successfully. Monitoring connection..."

# 持续监控连接是否成功
RETRY_COUNT=0
while true; do
    sleep 30

    # 捕获状态，即使命令失败也不让脚本退出
    status=$(sudo -u warpuser warp-cli --accept-tos status 2>/dev/null || echo "disconnected")

    if [[ $status != *"Connected"* ]]; then
        echo "WARP connection lost. Attempting to reconnect... (Attempt $((RETRY_COUNT+1)))"

        # 尝试重连，如果重连失败，等待时间逐渐增加 (5s, 10s, 15s...)
        if ! sudo -u warpuser warp-cli --accept-tos connect; then
            local backoff_time=$((5 + RETRY_COUNT * 5))
            backoff_time=$((backoff_time > 30 ? 30 : backoff_time)) # 最大不超过30秒
            echo "Reconnect failed. Retrying in ${backoff_time}s..."
            sleep $backoff_time
            ((RETRY_COUNT++))
        else
            RETRY_COUNT=0 # 重连成功，重置计数器
        fi
    fi
done
