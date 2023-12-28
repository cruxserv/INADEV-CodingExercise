import subprocess
import os
import requests

## Assumes tf is setup to connect to the AWS account. Also assumes using AWS Direct Connect to
##securely connect local environment to the AWS VPC, or this is running from some resource on the VPC,
##such as an EC2 or Lambda with necessary permissions. AWS CLI, Python Requests Module, & Terraform should 
#be installed as well.

# This function clones the git repo to the computer to use the files for all necessary steps
def clone_repo(repo_url, local_path):
    subprocess.run(["git", "clone", repo_url, local_path], check=True)

# This function will require tf files in the same director as this script
def run_terraform(terraform_dir):
    # Change the current working directory to where the Terraform files are
    os.chdir(terraform_dir)

    # Runs the terraform commands
    subprocess.run(["terraform", "init"], check=True)
    subprocess.run(["terraform", "apply", "-auto-approve"], check=True)

def create_jenkins_pipeline(jenkins_url, job_name, repo_url):
    # Using basic Jenkins API call from https://wiki.jenkins-ci.org/display/JENKINS/Remote+access+API
    # Jenkins API call to create a pipeline job with the Jenkinsfile from the repo
    create_job_url = f"{jenkins_url}:8080/createItem?name={job_name}"
    config_xml = f"""
    <flow-definition plugin="workflow-job@2.40">
      <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.92">
        <scm class="hudson.plugins.git.GitSCM" plugin="git@4.7.1">
          <configVersion>2</configVersion>
          <userRemoteConfigs>
            <hudson.plugins.git.UserRemoteConfig>
              <url>{repo_url}</url>
            </hudson.plugins.git.UserRemoteConfig>
          </userRemoteConfigs>
          <branches>
            <hudson.plugins.git.BranchSpec>
              <name>*/main</name>
            </hudson.plugins.git.BranchSpec>
          </branches>
          <scriptPath>Jenkinsfile</scriptPath>
        </scm>
      </definition>
    </flow-definition>
    """
    response = requests.post(
        create_job_url,
        data=config_xml,
        headers={"Content-Type": "application/xml"},
        auth=("admin", "password"),
    )
    return response.status_code

def trigger_jenkins_pipeline(jenkins_url, job_name):
    # Trigger the pipeline
    build_url = f"{jenkins_url}:8080/job/{job_name}/build"
    response = requests.post(build_url, auth=("admin", "password"))
    return response.status_code

if __name__ == "__main__":
    # May need to adjust based on the configuration of github cloning
    local_path = "/desktop/projects"
    local_dir = f"{local_path}/INADEV-CodingExercise"
    # Set these variables as per Jenkins setup, eventually put in Secrets Manager?
    jenkins_url = "http://jenkins.simple.com"
    job_name = "weather-service-deploy"
    repo_url = "https://github.com/cruxserv/INADEV-CodingExercise.git"
    clone_repo(repo_url, local_path)
    run_terraform(local_dir)
    create_jenkins_pipeline(jenkins_url, job_name, repo_url)
    trigger_jenkins_pipeline(jenkins_url, job_name)
