#!/usr/bin/env bash
set -euo pipefail
[ -d .git ] || { echo "Run inside repo root"; exit 1; }

git checkout -b feat/moto-smoke || git checkout feat/moto-smoke

# Add moto to dev deps (idempotent)
grep -q "^moto" requirements-dev.txt || cat >> requirements-dev.txt <<TXT
moto[s3,iam,dynamodb]>=5.0.0
TXT

# Simple Moto test
mkdir -p tests
cat > tests/test_moto_smoke.py <<'PY'
from moto import mock_aws
import boto3

def test_moto_smoke():
    with mock_aws():
        boto3.client("iam", region_name="us-east-2")
        boto3.client("dynamodb", region_name="us-east-2")
        assert True
PY

git add -A
git commit -m "tests: add moto smoke test" || true
source .venv/bin/activate 2>/dev/null || true
pip install -r requirements-dev.txt
pytest -q
git push -u origin feat/moto-smoke
gh pr create -f -B main -H feat/moto-smoke
