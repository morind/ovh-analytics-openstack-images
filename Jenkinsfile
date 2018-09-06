pipeline {
    agent {
        dockerfile {
            filename 'Dockerfile'
            args "-u root:root"
        }
    }
    environment {
        OS_AUTH_URL             = 'https://auth.cloud.ovh.net/v2.0'
        OS_ENDPOINT_TYPE        = 'publicURL'
        OS_INTERFACE            = 'public'
        OS_IDENTITY_API_VERSION = '2'
        OS_REGION_NAME          = credentials('OS_REGION_NAME')
        OS_USERNAME             = credentials('OS_USERNAME')
        OS_PASSWORD             = credentials('OS_PASSWORD')
        OS_PROJECT_NAME         = credentials('OS_PROJECT_NAME')
        OS_PROJECT_ID           = credentials('OS_PROJECT_ID')
        GPG_PASS                = credentials('GPG_PASS')
        KEY                     = credentials('KEY')
        IV                      = credentials('IV')
    }

    stages {
        stage('Prepare build environment') {
            when{
                branch 'master'
            }
            steps{
              slackSend (color: '#FFFF00', message: "STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
              sh 'openssl aes-256-cbc -K $KEY -iv $IV -in .ovh.ci.gpg.enc -d -a -out .ovh.ci.gpg'
              sh 'gpg --import .ovh.ci.gpg'
            }
        }
        stage('Build common image') {
            when{
              anyOf{
                  branch 'master';
                  branch 'development';
              }
            }
            steps {
                sh 'test/run.sh packer-common.json $OS_REGION_NAME'
            }
        }
        stage('Build Guacamole image') {
            when{
              anyOf{
                  branch 'master';
                  branch 'development';
              }
            }
            steps {
                sh 'test/run.sh packer-guacamole.json $OS_REGION_NAME'
            }
        }
        stage('Build IPA image') {
            when{
              anyOf{
                  branch 'master';
                  branch 'development';
              }
            }
            steps {
                sh 'test/run.sh packer-ipa.json $OS_REGION_NAME'
            }
        }
        stage('Build MySQL image') {
            when{
              anyOf{
                  branch 'master';
                  branch 'development';
              }
            }
            steps {
                sh 'test/run.sh packer-mysql.json $OS_REGION_NAME'
            }
        }
        stage('Build Ambari image') {
            when{
              anyOf{
                  branch 'master';
                  branch 'development';
              }
            }
            steps {
                sh 'test/run.sh packer-ambari.json $OS_REGION_NAME'
            }
        }
        stage('Publish images'){
            when{
                branch 'master'
            }
            steps {
                sh 'test/publish.sh packer-common.json $OS_REGION_NAME'
                sh 'test/publish.sh packer-guacamole.json $OS_REGION_NAME'
                sh 'test/publish.sh packer-ipa.json $OS_REGION_NAME'
                sh 'test/publish.sh packer-mysql.json $OS_REGION_NAME'
                sh 'test/publish.sh packer-ambari.json $OS_REGION_NAME'
            }
        }
    }
    post {
          success{
              slackSend (color: '#00FF00', message: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
          }
          failure{
              slackSend (color: '#FF0000', message: "FAIL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
          }
    }
}