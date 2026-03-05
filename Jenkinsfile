pipeline {
    agent any

    environment {
        IMAGE_REPO = "balu051989/frame-v2"
        IMAGE_TAG = "${BUILD_NUMBER}"
        IMAGE = "${IMAGE_REPO}:${IMAGE_TAG}"
    }

    stages {

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
                sh 'kubectl set image deployment/frame-v2 frame-container=$IMAGE'
                sh 'kubectl rollout status deployment/frame-v2'
            }
        }
    }
}
