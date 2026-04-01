#!/bin/bash

# 检查 PROXY_USER 和 PROXY_PASSWORD 是否都已设置且不为空
if [[ -n "$PROXY_USER" && -n "$PROXY_PASSWORD" ]]; then
    # 如果设置了环境变量，则启动带认证的代理服务
    # 格式：协议://用户名:密码@:端口
    exec /usr/local/bin/gost -L "${PROXY_USER}:${PROXY_PASSWORD}@:1080"
else
    # 如果没有设置环境变量，则启动无认证的代理服务
    exec /usr/local/bin/gost -L :1080
fi