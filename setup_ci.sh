#!/usr/bin/env bash
set -euo pipefail
[ -d .git ] || { echo "Run inside repo root"; exit 1; }

# Create folders
mkdir -p .github/workflows tests jenkins/scripts k8s/charts/policy-audit/templates

# --- GitHub Actions workflow ---
cat > .github/workflows/ci.yml <<'YAML'
name: CI
on:
  pull_request:
permissions:
  contents: read
  id-token: write
jobs:
  ci:
    runs-on: ubuntu-latest
    env:
      TF_INPUT: false
      AWS_REGION: us-east-2
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install dev deps
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements-dev.txt
      - name: Run Python tests (pytest)
        run: pytest -q --cov=lambda --cov-report=xml
      - name: Run unit tests (unittest)
        run: python -m unittest -v
      - name: Install Terraform & Helm
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: '1.6.6'
      - run: |
          curl -L https://get.helm.sh/helm-v3.14.4-linux-amd64.tar.gz | tar xz
          sudo mv linux-amd64/helm /usr/local/bin/helm
      - name: Terraform fmt/validate (dev)
        working-directory: terraform/envs/dev
        run: |
          terraform fmt -check
          terraform init -input=false -backend=false
          terraform validate
      - name: Helm lint & template (policy-audit)
        run: |
          helm lint k8s/charts/policy-audit || true
          helm template policy-audit k8s/charts/policy-audit > /tmp/policy-audit.yaml
      - uses: actions/upload-artifact@v4
        with:
          name: k8s-render
          path: /tmp/policy-audit.yaml
YAML

# --- test/dev dependencies ---
cat > requirements-dev.txt <<'TXT'
boto3
botocore
pytest
pytest-cov
moto[s3,iam,dynamodb]>=5.0.0
coverage
TXT

# --- pytest (moto) ---
cat > tests/test_lambda_pytest.py <<'PY'
import json, os
from moto import mock_aws
import boto3
os.environ['TABLE_NAME'] = 'test-user-access'
os.environ['ROLE_TEMPLATE'] = '{userid}-role'
@mock_aws
def test_detach_flow_pytest():
    ddb = boto3.client('dynamodb', region_name='us-east-2')
    ddb.create_table(
        TableName='test-user-access',
        KeySchema=[{'AttributeName':'userid','KeyType':'HASH'}],
        AttributeDefinitions=[{'AttributeName':'userid','AttributeType':'S'}],
        BillingMode='PAY_PER_REQUEST',
    )
    boto3.resource('dynamodb', region_name='us-east-2').Table('test-user-access').put_item(Item={
        'userid':'u1',
        'required_policies':['arn:aws:iam::123:policy/test-policy1'],
        'role_name':'test-userid1-role'
    })
    iam = boto3.client('iam', region_name='us-east-2')
    iam.create_role(RoleName='test-userid1-role',
                    AssumeRolePolicyDocument=json.dumps({"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}))
    p1 = iam.create_policy(PolicyName='test-policy1', PolicyDocument=json.dumps({"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:ListAllMyBuckets"],"Resource":"*"}]}))
    p2 = iam.create_policy(PolicyName='test-policy2', PolicyDocument=json.dumps({"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:ListBucket"],"Resource":"*"}]}))
    iam.attach_role_policy(RoleName='test-userid1-role', PolicyArn=p1['Policy']['Arn'])
    iam.attach_role_policy(RoleName='test-userid1-role', PolicyArn=p2['Policy']['Arn'])
    from lambda.main import lambda_handler
    resp = lambda_handler({"queryStringParameters":{"userid":"u1","dry_run":"false"}}, None)
    body = json.loads(resp['body'])
    assert resp['statusCode'] == 200
    assert p2['Policy']['Arn'] in body['detached_now']
    assert p1['Policy']['Arn'] in body['kept']
PY

# --- unittest (moto) ---
cat > tests/test_lambda_unittest.py <<'PY'
import unittest, os
from moto import mock_aws
import boto3
class TestLambdaUnittest(unittest.TestCase):
    @mock_aws
    def test_missing_user(self):
        os.environ['TABLE_NAME'] = 'test-user-access'
        ddb = boto3.client('dynamodb', region_name='us-east-2')
        ddb.create_table(
            TableName='test-user-access',
            KeySchema=[{'AttributeName':'userid','KeyType':'HASH'}],
            AttributeDefinitions=[{'AttributeName':'userid','AttributeType':'S'}],
            BillingMode='PAY_PER_REQUEST',
        )
        from lambda.main import lambda_handler
        resp = lambda_handler({"queryStringParameters":{"userid":"nope"}}, None)
        self.assertEqual(resp['statusCode'], 404)
if __name__ == '__main__':
    unittest.main()
PY

# --- Jenkins helpers (optional) ---
cat > jenkins/Jenkinsfile <<'JENKINS'
pipeline {
  agent any
  options { timestamps(); ansiColor('xterm') }
  environment { AWS_REGION = 'us-east-2' }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Package Lambda') {
      steps { sh 'bash jenkins/scripts/zip_lambda.sh' }
      post { success { archiveArtifacts artifacts: 'files/lambda.zip', fingerprint: true } }
    }
    stage('Terraform Plan (dev)') {
      steps {
        dir('terraform/envs/dev') {
          sh '''
            terraform init -input=false
            terraform validate
            terraform plan -out=tfplan
          '''
        }
      }
      post { success { archiveArtifacts artifacts: 'terraform/envs/dev/tfplan', fingerprint: true } }
    }
    stage('Apply to dev (approval)') {
      steps {
        input message: 'Apply to dev?', ok: 'Apply'
        dir('terraform/envs/dev') { sh 'terraform apply -auto-approve tfplan' }
      }
    }
    stage('Smoke test') {
      steps { sh 'bash jenkins/scripts/smoke_test.sh' }
    }
  }
}
JENKINS

cat > jenkins/scripts/zip_lambda.sh <<'SH2'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p files
cd lambda
zip -qr ../files/lambda.zip main.py
cd -
echo "Created files/lambda.zip"
SH2
chmod +x jenkins/scripts/zip_lambda.sh

cat > jenkins/scripts/smoke_test.sh <<'SH3'
#!/usr/bin/env bash
set -euo pipefail
if [ -n "${INVOKE_URL:-}" ]; then
  curl -sS "${INVOKE_URL}/user-access?userid=test-user&dry_run=true" | jq .
else
  aws lambda invoke --function-name test-user-access /tmp/out.json >/dev/null
  cat /tmp/out.json | jq .
fi
SH3
chmod +x jenkins/scripts/smoke_test.sh

# --- Minimal Helm chart (optional) ---
cat > k8s/charts/policy-audit/Chart.yaml <<'YAML'
apiVersion: v2
name: policy-audit
version: 0.1.0
description: Nightly dry-run audit against the private API
YAML

cat > k8s/charts/policy-audit/values.yaml <<'YAML'
image:
  repository: public.ecr.aws/docker/library/python
  tag: "3.12-alpine"
schedule: "0 3 * * *"
apiInvokeUrl: ""
userid: "test-user"
YAML

cat > k8s/charts/policy-audit/templates/cronjob.yaml <<'YAML'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: policy-audit
spec:
  schedule: {{ .Values.schedule | quote }}
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: auditor
              image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
              command: ["/bin/sh","-c"]
              args:
                - |
                  apk add --no-cache curl jq;
                  curl -sS "{{ .Values.apiInvokeUrl }}/user-access?userid={{ .Values.userid }}&dry_run=true" | jq .
YAML

echo "All files created."
