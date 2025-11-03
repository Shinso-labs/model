#!/bin/bash
set -e

# start ollama in the background
ollama serve &
OLLAMA_PID=$!

# wait for the API to come up
# we'll just poll the /api/tags endpoint
until curl -s http://localhost:11434/api/tags >/dev/null 2>&1; do
  sleep 0.2
done

ollama create solmover -f /models/Modelfile || true

# bring ollama back to foreground (replace shell with the server)
wait $OLLAMA_PID