#!/usr/bin/env bash
set -euo pipefail
mkdir -p files
cd lambda_func
zip -qr ../files/lambda.zip main.py
cd -
echo "Created files/lambda.zip"
