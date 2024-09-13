pipeline {
    agent {
        label 'AGENT-1'
    }
    options {
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
        ansiColor('xterm')
    }
    parameters { //we should define params here, so that CI sends appversion here and it takes and prints
        string(name: 'appVersion', defaultValue: '1.0.0', description: 'What is the application version?')
    }
    environment{
        def appVersion = '' //variable declaration
        def nexusUrl = '107.23.30.219:8081' //need to change everytime
    }
    stages {
        stage('print the version'){
            steps{
                script{
                    echo "Application version: ${params.appVersion}"
                }
            }
        }
        stage('Init'){
            steps{
                sh """
                    cd terraform
                    terraform init
                """
            }
        }
        stage('Plan'){
            steps{
                sh """
                    pwd
                    cd terraform
                    terraform plan -var="app_version=${params.appVersion}" 
                """
            }
        }

        stage('Deploy'){
            steps{
                sh """
                    cd terraform
                    terraform apply -auto-approve -var="app_version=${params.appVersion}"
                """
            }
        }
    }
    post { 
        always { 
            echo 'I will always say Hello again!'
            deleteDir()
        }
        success { 
            echo 'I will run when pipeline is success'
        }
        failure { 
            echo 'I will run when pipeline is failure'
        }
    }
}