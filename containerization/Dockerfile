FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0
# Point Ollama's internal model store somewhere writable by the OVH user
ENV OLLAMA_MODELS=/workspace/.ollama/models

# --- install deps + Ollama as root ---
RUN apt-get update && apt-get install -y \
    curl ca-certificates gnupg libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://ollama.ai/install.sh | sh

# --- prepare runtime dirs ---
# 1. /workspace      (OVH requires this, will become HOME, must be writable by UID 42420)
# 2. /workspace/.ollama (ollama will write keys, model blobs here)
# 3. /models         (we'll stash the big gguf + Modelfile here, read-only is fine)
RUN mkdir -p /workspace/.ollama \
    && mkdir -p /models

# Copy model weights and Modelfile into /models.
# We keep these owned by 42420 so the non-root user can read them.
COPY --chown=42420:42420 solmover.gguf /models/solmover.gguf
COPY --chown=42420:42420 Modelfile     /models/Modelfile

# Copy entrypoint script into /workspace (that's HOME later)
COPY --chown=42420:42420 entrypoint.sh /workspace/entrypoint.sh
RUN chmod +x /workspace/entrypoint.sh

# OVH wants HOME=/workspace and container to run as UID 42420,
# so set that up now.
WORKDIR /workspace
ENV HOME=/workspace

# Give OVH user ownership of /workspace and /models so it can read /models
# and write to /workspace/.ollama at runtime.
RUN chown -R 42420:42420 /workspace /models

# Expose Ollama's API port
EXPOSE 11434

# Drop privileges: OVH will run as this anyway, but we make it explicit for local parity.
USER 42420:42420

# At runtime, entrypoint.sh will:
#   1. start ollama serve in background
#   2. wait for it
#   3. ollama create qwen3-moe -f /models/Modelfile
#   4. keep serving
CMD ["/workspace/entrypoint.sh"]