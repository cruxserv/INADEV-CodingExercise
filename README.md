# INADEV-CodingExercise

Prompt:
Cloud Engineering / Infrastructure-as-Code:
Provide infrastructure-as-code using Terraform that will create a Kubernetes cluster in AWS. You are free to use publicly available modules / components, but it is expected that you understand what those modules are doing; we may ask questions about the logic within those modules. (You can assume the IAM user running this has full admin permission in AWS and is running in us-east-2.)
 
Continuous Integration / Continuous Deployment:
In the above Kubernetes cluster, install Jenkins to act as a CI/CD tool. The administrative interface for the tool should be publicly accessible (although protected by Username and Password).
 
Software Development:
Create a microservice that provides the current weather for Washington, DC. It can be either a simple web page or a REST endpoint. (You can obtain the weather from a free API like https://open-meteo.com/). You may use any of the following languages to create the service: JavaScript, Python, Java, Go, or C#.
The code for the service should be stored in a public Git repo (preferably GitHub). The service should be built by a pipeline in the above CI/CD tool, deployed to the above Kubernetes cluster, and publicly accessible.
 
Tying it all together:
Finally, please provide a single script (either shell script or in a language like Python or Go). This script should (from a single invocation):
                                                               i.      Run the IaC, creating the Kubernetes Cluster
                                                             ii.      Install the CI/CD tool into Kubernetes.
                                                           iii.      Create a pipeline for your micro-service.
                                                            iv.      Execute the pipeline for your micro-service (thus building and deploying it)
Provide any additional instructions / assumptions you have made for running the script.


Manual Steps

1. Run the run_it.py script to build the resources in AWS using Terraform, create the Jenkins pipeline, and deploy the application
2. Send a request from within the cluster or VPC to the microservice using the Kubernetes DNS service name. http://weather-service.weather-service.svc.cluster.local/weather
