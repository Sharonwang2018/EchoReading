#!/bin/bash
# Hi-Doo 绘读：一键启动（UI + API 同源，HTTPS）
# 1. 确保数据库已建: createdb echo_reading && psql -d echo_reading -f sql/schema.sql
# 2. 首次 HTTPS 需生成证书: ./scripts/gen_certs.sh
# 3. 配置豆包参数（必填）: 见 docs/DOUBAO_SETUP.md
#    export DOUBAO_API_KEY=你的API_Key
#    export DOUBAO_ARK_MODEL=doubao-seed-2-0-pro-260215
#    export DOUBAO_ASR_APPID=xxx            # 录音转写
#    export DOUBAO_ASR_ACCESS_KEY=xxx   # 录音转写 + 边说边识别共用
# 4. ./run_all.sh
# 手机测试无证书警告: HTTP=1 ./run_all.sh

cd "$(dirname "$0")"

LOCAL_IP=10.0.0.138
USE_HTTPS=false
[ -f api/certs/cert.pem ] && [ -f api/certs/key.pem ] && [ "${HTTP:-}" != "1" ] && USE_HTTPS=true
SCHEME=http; [ "$USE_HTTPS" = true ] && SCHEME=https
API_BASE="${SCHEME}://${LOCAL_IP}:3000"

if [ -z "${DOUBAO_API_KEY:-}" ]; then
  echo "⚠️  请先配置豆包参数，详见 docs/DOUBAO_SETUP.md"
  echo "   export DOUBAO_API_KEY=你的Key"
  echo "   export DOUBAO_ARK_MODEL=doubao-seed-2-0-pro-260215"
  echo ""
fi

echo "Building Flutter web (API_BASE=$API_BASE)..."
flutter build web \
  --dart-define=API_BASE_URL="$API_BASE" \
  --dart-define=DOUBAO_API_KEY="${DOUBAO_API_KEY:-02c2b436-a3fc-43a2-8696-f41955eb2fba}" \
  --dart-define=DOUBAO_ARK_MODEL="${DOUBAO_ARK_MODEL:-doubao-seed-2-0-pro-260215}" \
  --dart-define=DOUBAO_ASR_APPID="${DOUBAO_ASR_APPID:-}" \
  --dart-define=DOUBAO_ASR_ACCESS_KEY="${DOUBAO_ASR_ACCESS_KEY:-}"

echo ""
if [ "$USE_HTTPS" = true ]; then
  echo "📱 访问地址: https://10.0.0.138:3000 （本机或局域网设备均可）"
  echo "   UI 与 API 同源，HTTPS 已启用"
  echo ""
  cd api && HTTPS=1 npm start
else
  [ -f api/certs/cert.pem ] && [ -f api/certs/key.pem ] || echo "⚠️  首次 HTTPS 请先执行: ./scripts/gen_certs.sh"
  echo "   使用 HTTP 启动（手机无证书警告）"
  echo "📱 访问地址: http://10.0.0.138:3000"
  echo ""
  cd api && npm start
fi
