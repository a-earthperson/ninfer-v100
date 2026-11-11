#!/usr/bin/env bash
# Optionally fetch one .ninfer artifact from Hugging Face into $NINFER_MODEL_DIR, then exec the
# command. `hf download --local-dir` skips files whose local metadata matches the remote revision
# and falls back to the existing file when the Hub is unreachable.
#
#   NINFER_MODEL_REPO      Hugging Face repository, e.g. neroued/Qwen3.8-27B-nvfp4-NInfer
#   NINFER_MODEL_FILE      artifact filename within the repository, e.g. qwen3_8_27b_nvfp4.ninfer
#   NINFER_MODEL_REVISION  optional branch, tag, or commit
#   NINFER_MODEL_DIR       download directory (default /models)
#   HF_TOKEN               optional token for gated or private repositories
set -euo pipefail

model_dir="${NINFER_MODEL_DIR:-/models}"

if [[ -n "${NINFER_MODEL_REPO:-}" ]]; then
    if [[ -z "${NINFER_MODEL_FILE:-}" ]]; then
        echo "ninfer-entrypoint: NINFER_MODEL_FILE is required with NINFER_MODEL_REPO" >&2
        exit 64
    fi
    args=(download "${NINFER_MODEL_REPO}" "${NINFER_MODEL_FILE}" --local-dir "${model_dir}")
    if [[ -n "${NINFER_MODEL_REVISION:-}" ]]; then
        args+=(--revision "${NINFER_MODEL_REVISION}")
    fi
    mkdir -p "${model_dir}"
    echo "ninfer-entrypoint: ensuring ${NINFER_MODEL_REPO}/${NINFER_MODEL_FILE} in ${model_dir}" >&2
    hf "${args[@]}" >&2
fi

exec "$@"
