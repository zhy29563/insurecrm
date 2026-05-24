#!/usr/bin/env bash
# 下载 Sherpa-ONNX Paraformer 中文离线语音识别模型
#
# 用法：
#   bash scripts/download_sherpa_models.sh
#
# 输出（assets/sherpa_models/paraformer-zh/）：
#   model.int8.onnx  - ONNX 模型文件 (~217MB)
#   tokens.txt       - Token 列表文件 (~74KB)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/assets/sherpa_models/paraformer-zh"

# 模型来源: sherpa-onnx GitHub Releases
MODEL_BASE_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-paraformer-bilingual-zh-en"
MODEL_FILE="model.int8.onnx"
TOKENS_FILE="tokens.txt"

mkdir -p "$OUTPUT_DIR"

download_file() {
    local url="$1"
    local output="$2"
    local name="$3"

    if [ -f "$output" ] && [ "$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output")" -gt 1000 ]; then
        echo "✅ $name 已存在，跳过下载"
        return 0
    fi

    echo "⬇️  正在下载 $name ..."
    echo "   URL: $url"

    # 尝试 curl，失败则回退到 wget
    if command -v curl &>/dev/null; then
        curl -L --progress-bar --retry 3 --retry-delay 5 -o "$output" "$url"
    elif command -v wget &>/dev/null; then
        wget --progress=bar:force:noscroll --tries=3 -O "$output" "$url"
    else
        echo "❌ 错误: 需要安装 curl 或 wget"
        exit 1
    fi

    if [ ! -f "$output" ] || [ "$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output")" -lt 1000 ]; then
        echo "❌ $name 下载失败或文件不完整"
        rm -f "$output"
        exit 1
    fi

    echo "✅ $name 下载完成"
}

echo "========================================="
echo " Sherpa-ONNX Paraformer 模型下载工具"
echo "========================================="
echo ""

# 下载模型文件
download_file "$MODEL_BASE_URL/$MODEL_FILE" "$OUTPUT_DIR/$MODEL_FILE" "Paraformer ONNX 模型 (int8)"

# 下载 tokens 文件
download_file "$MODEL_BASE_URL/$TOKENS_FILE" "$OUTPUT_DIR/$TOKENS_FILE" "Token 列表"

# 输出结果
echo ""
echo "=== 输出文件 ==="
ls -lh "$OUTPUT_DIR/"

echo ""
echo "=== 完成 ==="
echo "模型文件已保存到 assets/sherpa_models/paraformer-zh/"
echo ""
echo "提示: 如果推送 Git 时遇到大文件问题,"
echo "     请确认 .gitignore 中已包含:"
echo "       assets/sherpa_models/**/*.onnx"
echo "       assets/sherpa_models/**/tokens.txt"
