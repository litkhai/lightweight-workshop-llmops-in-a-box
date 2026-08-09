#!/usr/bin/env bash
# Pull a model into the Ollama container.
# Usage: ./scripts/pull-model.sh [model]
# Default model: qwen2.5:1.5b (~1 GB, good balance of speed and quality on CPU)
#
# Other options by size:
#   qwen2.5:0.5b   ~400 MB   fastest, basic quality
#   qwen2.5:1.5b   ~1 GB     recommended default
#   qwen2.5:3b     ~2 GB     better reasoning, needs ≥8 GB RAM
#   phi4-mini      ~2.5 GB   strong at instruction-following
#   gemma2:2b      ~1.6 GB   good multilingual quality
set -euo pipefail

MODEL="${1:-qwen2.5:1.5b}"

echo "Pulling model: $MODEL"
echo "This may take a few minutes on first run..."
docker compose exec ollama ollama pull "$MODEL"

echo ""
echo "Done. '$MODEL' is ready."
echo "The litellm_config.yaml uses 'ollama/qwen2.5:1.5b' by default."
echo "If you pulled a different model, update config/litellm_config.yaml accordingly."
