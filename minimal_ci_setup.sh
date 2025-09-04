#!/usr/bin/env bash
set -euo pipefail

# Must run from repo root
[ -d .git ] || { echo "ERROR: Run this inside your repo root (where .git exists)."; exit 1; }

# Create/checkout a clean feature branch
git checkout -B feat/min-ci

# Ensure folder layout
mkdir -p lambda_func tests .github/workflows

# If old folder named 'lambda' exists, rename it (lambda is a Python keyword)
if [ -d lambda ] && [ ! -d lambda_func ]; then
  git mv lambda lambda_func || { mv lambda lambda_func; git add -A; }
fi

# Make it a package for local tests
: > lambda_func/__init__.py

# Create a tiny handler if you don't already have one
if [ ! -f lambda_func/main.py ]; then
cat > lambda_func/main.py <<'PY'
def lambda_handler(event, context):
    return {"statusCode": 200, "body": "ok"}
PY
fi

# Minimal test: just import the handler
cat > tests/test_imports.py <<'PY'
import importlib
def test_can_import_lambda_handler():
    mod = importlib.import_module("lambda_func.main")
    assert hasattr(mod, "lambda_handler")
    assert callable(mod.lambda_handler)
PY

# Minimal dev requirements
cat > requirements-dev.txt <<'TXT'
pytest
TXT

# Minimal GitHub Actions workflow (Python tests only)
cat > .github/workflows/ci-minimal.yml <<'YAML'
name: CI (minimal python)
on:
  pull_request:
jobs:
  tests:
    runs-on: ubuntu-latest
    env:
      PYTHONPATH: ${{ github.workspace }}
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

# Commit changes
git add -A
git commit -m "Minimal CI: Python import test + lambda_func package" || true

# Run tests locally (optional but recommended)
if command -v python3.12 >/dev/null 2>&1; then PY=python3.12; else PY=python3; fi
$PY -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q

# Push the branch
git push -u origin feat/min-ci

echo "Done. Open a Pull Request for branch: feat/min-ci"
