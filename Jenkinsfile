pipeline {
    agent any

    environment {
        IMAGE = "balu051989/frame_v2-web:latest"
    }

    stages {
        stage('Stop Port-Forward (If Any)') {
            steps {
                sh '''
                    if [ -f /tmp/frame-v2-port-forward.pid ]; then
                        kill $(cat /tmp/frame-v2-port-forward.pid) || true
                        rm -f /tmp/frame-v2-port-forward.pid
                    fi
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $IMAGE .'
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh 'docker push $IMAGE'
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                sh 'kubectl rollout restart deployment frame-v2'
            }
        }

        stage('Start Port-Forward') {
            steps {
                sh '''
                    nohup kubectl port-forward --address 0.0.0.0 svc/frame-v2 8085:8080 >/tmp/frame-v2-port-forward.log 2>&1 &
                    echo $! >/tmp/frame-v2-port-forward.pid
                '''
            }
        }
    }
}
