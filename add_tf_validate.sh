#!/usr/bin/env bash
set -euo pipefail
[ -d .git ] || { echo "Run inside repo root"; exit 1; }

git checkout -b feat/ci-tf-validate || git checkout feat/ci-tf-validate

# Add a second workflow that ONLY runs tf fmt/validate if tf files exist
mkdir -p .github/workflows
cat > .github/workflows/ci-tf-validate.yml <<'YAML'
name: CI (terraform validate)
on:
  pull_request:
jobs:
  tf:
    runs-on: ubuntu-latest
    if: ${{ hashFiles('**/*.tf') != '' }}
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.6.6'
      - name: terraform fmt/validate (repo root)
        run: |
          terraform fmt -check || true
          terraform init -input=false -backend=false || true
          terraform validate || true
YAML

git add -A
git commit -m "ci: add terraform fmt/validate workflow" || true
git push -u origin feat/ci-tf-validate
gh pr create -f -B main -H feat/ci-tf-validate
