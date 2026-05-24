#!/usr/bin/env bash
# 准备中文语义嵌入模型 (BAAI/bge-small-zh-v1.5) 的 ONNX 版本
#
# 用法：
#   bash scripts/prepare_embedding_model.sh
#
# 输出：
#   assets/embedding_model/model.onnx    - ONNX 模型文件 (~91MB)
#   assets/embedding_model/vocab.txt     - BERT vocab 文件 (~107KB)
#   assets/embedding_model/config.json   - 模型配置
#   assets/embedding_model/tokenizer.json - Tokenizer 配置

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_DIR/assets/embedding_model"
VENV_DIR="$PROJECT_DIR/.venv"

mkdir -p "$OUTPUT_DIR"

# 创建虚拟环境（如不存在）
if [ ! -d "$VENV_DIR" ]; then
  echo "=== 创建 Python 虚拟环境 ==="
  python3 -m venv "$VENV_DIR"
fi

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

# 安装依赖（仅 CPU，不安装 torch GPU）
echo "=== 安装依赖（CPU only）==="
pip install --upgrade pip -q
pip install optimum[onnxruntime] onnx "transformers>=4.36,<4.58" -q

echo "=== 下载并导出 bge-small-zh-v1.5 ONNX 模型（CPU only）==="

# 使用 HF 镜像加速（国内环境）
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"

# 使用 optimum 导出 ONNX 模型，仅 CPU provider
python3 << 'PYEOF'
from optimum.onnxruntime import ORTModelForFeatureExtraction
from transformers import AutoTokenizer

model_name = 'BAAI/bge-small-zh-v1.5'
output_dir = 'assets/embedding_model'

print(f'下载模型: {model_name}...')
model = ORTModelForFeatureExtraction.from_pretrained(model_name, export=True, provider='CPUExecutionProvider')
tokenizer = AutoTokenizer.from_pretrained(model_name)

print(f'保存 ONNX 模型到: {output_dir}')
model.save_pretrained(output_dir)
tokenizer.save_pretrained(output_dir)

print('完成!')
PYEOF

# 重命名模型文件（optimum 导出的文件名可能不同）
if [ -f "$OUTPUT_DIR/model.onnx" ]; then
  echo "模型文件已就绪: model.onnx"
elif [ -f "$OUTPUT_DIR/model_optimized.onnx" ]; then
  mv "$OUTPUT_DIR/model_optimized.onnx" "$OUTPUT_DIR/model.onnx"
  echo "重命名 model_optimized.onnx -> model.onnx"
fi

# 清理不需要的文件
rm -f "$OUTPUT_DIR/model_optimized.onnx"

# 检查输出
echo ""
echo "=== 输出文件 ==="
ls -lh "$OUTPUT_DIR/"

echo ""
echo "=== 完成 ==="
echo "模型文件已保存到 $OUTPUT_DIR"
echo "虚拟环境位于 $VENV_DIR (可删除: rm -rf $VENV_DIR)"
