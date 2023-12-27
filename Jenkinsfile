pipeline {
    agent any // Indicates that this pipeline can run on any available agent

    environment {
        // Define environment variables
        DOCKER_IMAGE = "weather-service:${BUILD_ID}" // Tag the Docker image with the name and Jenkins build ID (auto generated)
    }

    stages {
        stage('Checkout') {
            // Check out the source code from the github repository
            steps {
                git 'https://github.com/cruxserv/INADEV-CodingExercise.git'
            }
        }

        stage('Build Docker Image') {
            // Build the Docker image using the Dockerfile in the github repo
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}") // Builds and tags the Docker image
                }
            }
        }

        stage('Deploy to Kubernetes') {
            // Deploy the built Docker image to Kubernetes
            steps {
                script {
                    // Update the image name in the weather-service deployment manifest
                    sh "sed -i 's|image:.*|image: weather-service:${BUILD_ID}|' weather-service-deployment.yaml"
                    
                    // Apply the Kubernetes deployment manifest to the cluster & namespace
                    kubectl('apply -f weather-service-deployment.yaml', 'weather-service-namespace')
                }
            }
        }

        stage('Clean Up') {
            // Clean up the Docker image from the Jenkins node after deployment
            steps {
                script {
                    sh "docker rmi ${DOCKER_IMAGE}" // Removes the Docker image to free up disk space
                }
            }
        }
    }
}

// Helper Function
def kubectl(command, namespace = '') {
    if (namespace) {
        sh "kubectl ${command} -n ${namespace}"
    } else {
        sh "kubectl ${command}"
    }
}

// Maybe add a webhook eventually...?