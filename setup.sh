#!/bin/bash

# Exit on any error
set -e

# Define log file
LOGFILE="/home/ec2-user/terraform-setup.log"

# Redirect stdout and stderr to log file and console
exec > >(tee -a ${LOGFILE}) 2>&1

# Function to log success messages with timestamp
log_success() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') SUCCESS: $1"
}

# Function to log error messages with timestamp
log_error() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') ERROR: $1"
}

# Function to handle errors and exit
handle_error() {
  log_error "$1"
  exit 1
}

# Function to check if AWS CLI is configured
check_aws_cli() {
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    handle_error "AWS CLI is not configured correctly or IAM role is not assigned."
  fi
}

# Function to install dependencies
install_dependencies() {
  log_success "Installing dependencies..."
  sudo yum update -y || handle_error "System update failed"
  sudo yum install -y git yum-utils aws-cli || handle_error "Dependency installation failed"
  
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo || handle_error "Adding Terraform repo failed"
  sudo yum -y install terraform || handle_error "Terraform installation failed"
}

# Function to clone Bitbucket repo
clone_repo() {
  REPO_URL="https://<your-bitbucket-username>@bitbucket.org/<your-org>/<your-repo>.git"
  REPO_DIR="/home/ec2-user/<your-repo>"

  log_success "Cloning Bitbucket repository..."
  cd /home/ec2-user || handle_error "Cannot change to /home/ec2-user"
  
  if [ -d "$REPO_DIR" ]; then
    log_success "Repository already cloned. Pulling latest changes..."
    cd "$REPO_DIR" || handle_error "Cannot enter repo directory"
    git pull || handle_error "Git pull failed"
  else
    git clone "$REPO_URL" || handle_error "Git clone failed"
    cd "$REPO_DIR" || handle_error "Failed to enter repo directory"
  fi
}

# Function to run Terraform
run_terraform() {
  log_success "Running Terraform..."
  
  # Make sure you are inside the repo directory
  cd /home/ec2-user/<your-repo> || handle_error "Cannot change to repo directory"

  terraform init || handle_error "Terraform init failed"
  terraform plan -out=tfplan || handle_error "Terraform plan failed"

  # Optional: If you want to upload tfplan to S3
  # aws s3 cp tfplan s3://my-terraform-state-bucket/tfplan || handle_error "Upload to S3 failed"

  terraform apply -auto-approve tfplan || handle_error "Terraform apply failed"
}

# ---- Script Execution ---- #

log_success "Starting EC2 Terraform Provisioning Setup..."

check_aws_cli
install_dependencies
clone_repo
run_terraform

log_success "Terraform deployment completed successfully!"
