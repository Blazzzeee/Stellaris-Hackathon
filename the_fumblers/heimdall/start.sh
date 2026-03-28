#!/usr/bin/env bash

set -e

echo "🛡️  Booting Heimdall Ecosystem..."

# --- Config ---
CTRL_PORT=8000
AGENT_PORT=8001
SVC_PORT=5000
# --------------

echo "0. Cleaning up previous running instances (Ports $CTRL_PORT, $AGENT_PORT, $SVC_PORT)..."
fuser -k $CTRL_PORT/tcp 2>/dev/null || true
fuser -k $AGENT_PORT/tcp 2>/dev/null || true
fuser -k $SVC_PORT/tcp 2>/dev/null || true
fuser -k 8080/tcp 2>/dev/null || true  # Old default
pkill -f "uvicorn api:app" || true
pkill -f "uvicorn main:app" || true
pkill -f "python discord_bot/bot.py" || true
pkill -f "python api.py" || true
sleep 1

# Create a place to store logs
mkdir -p logs

export WEBHOOK_SECRET="super-secret-key"
export INFRA_API_KEY="heimdall"
export INFRA_API_URL="http://localhost:$CTRL_PORT"
export HEIMDALL_API_PORT=$CTRL_PORT
export HEIMDALL_AGENT_PORT=$AGENT_PORT

echo "1. Starting Heimdall Control Plane (API) on port $CTRL_PORT..."
uvicorn api:app --host 0.0.0.0 --port $CTRL_PORT > logs/api.log 2>&1 &
CTRL_PID=$!

echo "⏳ Waiting for Control Plane to be ready..."
for i in {1..10}; do
  if curl -s "http://localhost:$CTRL_PORT/health" > /dev/null; then
    echo "🟢 Control Plane is UP."
    break
  fi
  sleep 1
done

echo "2. Bootstrapping 'local-agent' node in database..."
python3 -c '
import os
from db import SessionLocal, Node
db = SessionLocal()
agent_port = os.environ.get("HEIMDALL_AGENT_PORT", "8001")
node = db.query(Node).filter_by(name="local-agent").first()
if not node:
    node = Node(name="local-agent", uuid="local-agent", host=f"http://localhost:{agent_port}", env="dev")
    db.add(node)
    db.commit()
db.close()
'

echo "3. Registering 'service-1' and 'worker-1' via API curl..."
curl -sS -X POST http://127.0.0.1:$CTRL_PORT/services \
  -H "X-API-Key: heimdall" \
  -H "Content-Type: application/json" \
  -d '{
    "service": "service-1",
    "node_name": "local-agent",
    "flake": "path:'"$PWD"'/examples/api_service",
    "commands": ["run"],
    "healthcheck_url": "http://127.0.0.1:'"$SVC_PORT"'/",
    "environment": "dev"
  }' > /dev/null

curl -sS -X POST http://127.0.0.1:$CTRL_PORT/services \
  -H "X-API-Key: heimdall" \
  -H "Content-Type: application/json" \
  -d '{
    "service": "worker-1",
    "node_name": "local-agent",
    "flake": "path:'"$PWD"'/examples/worker_service",
    "commands": ["run"],
    "environment": "dev"
  }' > /dev/null

echo ""

echo "4. Starting fastapi_agent (Node Agent) on port $AGENT_PORT..."
export WEBHOOK_URL="http://localhost:$CTRL_PORT/webhook"
cd fastapi_agent
uvicorn main:app --host 0.0.0.0 --port $AGENT_PORT > ../logs/node.log 2>&1 &
NODE_PID=$!
cd ..

echo "5. Starting Discord Bot..."
export SSL_CERT_FILE=$(python3 -m certifi)
python3 discord_bot/bot.py > logs/bot.log 2>&1 &
BOT_PID=$!

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Heimdall Infrastructure Ecosystem is UP!"
echo "   - Control Plane: http://localhost:$CTRL_PORT"
echo "   - Node Agent:    http://localhost:$AGENT_PORT"
echo "   - Discord Bot:   Active"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Use 'kill $CTRL_PID $NODE_PID $BOT_PID' to shutdown."
echo ""
