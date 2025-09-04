#!/usr/bin/env bash
set -euo pipefail
[ -d .git ] || { echo "Run inside repo root"; exit 1; }

# Ensure tests add repo to sys.path and set a default region locally
mkdir -p tests
cat > tests/conftest.py <<'PY'
import os, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-2")
os.environ.setdefault("AWS_REGION", "us-east-2")
PY

# Make CI export region too
mkdir -p .github/workflows
cat > .github/workflows/ci-minimal.yml <<'YAML'
name: CI (minimal python)
on:
  pull_request:
jobs:
  tests:
    runs-on: ubuntu-latest
    env:
      PYTHONPATH: ${{ github.workspace }}
      AWS_DEFAULT_REGION: us-east-2
      AWS_REGION: us-east-2
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install pytest
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements-dev.txt
      - name: Run tests
        run: pytest -q
YAML

git add -A
git commit -m "CI: set AWS region env; tests: add default AWS region" || true

# Run locally (optional)
source .venv/bin/activate 2>/dev/null || true
pytest -q || true

# Push so CI re-runs
git push
