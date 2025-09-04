pipeline {
  agent any
  options { timestamps(); skipDefaultCheckout(true) }   // <- removed ansiColor
  environment {
    PATH       = "/opt/homebrew/bin:/usr/local/bin:${env.PATH}"
    AWS_REGION = "us-east-2"
  }
  stage('Debug shell') {
  steps {
    sh '''
      echo "Shell: $0"
      which bash || true
      which sh || true
      ls -ld "$PWD"
      ls -ld "$PWD@tmp" || true
      uname -a
    '''
  }
}
  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'git --version'
        sh 'echo PATH=$PATH'
      }
    }
    stage('Package Lambda (zip)') {
      steps {
        sh '''
          set -euo pipefail
          mkdir -p files
          cd lambda
          zip -qr ../files/lambda.zip main.py
          cd -
          echo "Created files/lambda.zip"
        '''
      }
      post { success { archiveArtifacts artifacts: 'files/lambda.zip', fingerprint: true } }
    }
    stage('Terraform fmt/validate') {
      steps {
        sh '''
          set -euo pipefail
          TF_DIRS=$(git ls-files "*.tf" | xargs -n1 dirname | sort -u || true)
          if [ -z "$TF_DIRS" ]; then
            echo "No Terraform files found."
            exit 0
          fi
          for d in $TF_DIRS; do
            echo "== Validating $d =="
            terraform -chdir="$d" init -input=false -backend=false >/dev/null || true
            terraform -chdir="$d" fmt -check
            terraform -chdir="$d" validate || true
          done
        '''
      }
    }
    stage('Terraform plan (optional)') {
      when { expression { return env.AWS_ACCESS_KEY_ID?.trim() && env.AWS_SECRET_ACCESS_KEY?.trim() } }
      steps {
        sh '''
          set -euo pipefail
          TF_DIRS=$(git ls-files "*.tf" | xargs -n1 dirname | sort -u | uniq)
          for d in $TF_DIRS; do
            echo "== Planning $d =="
            terraform -chdir="$d" init -input=false
            terraform -chdir="$d" plan -out=tfplan || true
          done
        '''
      }
      post { success { archiveArtifacts artifacts: '**/tfplan', allowEmptyArchive: true } }
    }
  }
}
