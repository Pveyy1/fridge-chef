#!/bin/bash
set -e
cd "$(dirname "$0")"
PY=$(command -v /opt/homebrew/bin/python3 || command -v python3)
if [ ! -d .venv ]; then
  echo "First run: creating virtual environment..."
  "$PY" -m venv .venv
fi
.venv/bin/pip install -q -r requirements.txt
[ -f .env ] || cp .env.example .env
echo "Fridge Chef server on http://localhost:8000  (Ctrl+C to stop)"
exec .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --reload
