#!/bin/bash
set -euo pipefail

# Configuration
LOGFILE="/home/ec2-user/terraform-setup.log"
REPO_DIR="/home/ec2-user/EC2-Repo"

# Initialize logging
exec > >(tee -a "${LOGFILE}") 2>&1
exec 2> >(tee -a "${LOGFILE}" >&2)

# Logging functions
log() {
  local level=$1
  local message=$2
  echo "$(date +'%Y-%m-%d %H:%M:%S') ${level}: ${message}"
}

log_success() { log "SUCCESS" "$1"; }
log_info() { log "INFO" "$1"; }
log_error() { log "ERROR" "$1"; }

# Error handler (just logs and exits)
handle_error() {
  local exit_code=$?
  local message=$1
  log_error "${message} (Exit code: ${exit_code})"
  log_error "Terraform failed! Run 'terraform destroy' manually if needed."
  exit ${exit_code}
}

# Check AWS CLI
check_aws_cli() {
  log_info "Verifying AWS CLI configuration..."
  if ! aws sts get-caller-identity >/dev/null 2>&1; then
    handle_error "AWS CLI not configured or IAM role missing"
  fi
  log_success "AWS CLI is properly configured"
}

# Install dependencies
install_dependencies() {
  log_info "Updating system packages..."
  sudo yum update -y || handle_error "System update failed"
  
  log_info "Installing required packages..."
  sudo yum install -y git yum-utils || handle_error "Package installation failed"
  
  log_info "Adding HashiCorp repository..."
  sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo \
    || handle_error "Failed to add HashiCorp repository"
  
  log_info "Installing Terraform..."
  sudo yum install -y terraform || handle_error "Terraform installation failed"
  
  log_success "All dependencies installed successfully"
}

# Remove Terraform locks
remove_tf_locks() {
  log_info "Cleaning up any Terraform lock files..."
  local lockfiles=(
    "${REPO_DIR}/.terraform.lock.hcl"
    "${REPO_DIR}/terraform.tfstate.lock.info"
  )
  
  for lockfile in "${lockfiles[@]}"; do
    if [[ -f "${lockfile}" ]]; then
      rm -f "${lockfile}" || log_error "Failed to remove lock file: ${lockfile}"
    fi
  done
}

# Run Terraform operations
run_terraform() {
  log_info "Entering Terraform directory: ${REPO_DIR}"
  cd "${REPO_DIR}" || handle_error "Failed to enter Terraform directory"
  
  remove_tf_locks
  
  log_info "Running terraform init..."
  terraform init || handle_error "Terraform init failed"
  
  remove_tf_locks
  
  log_info "Running terraform plan..."
  terraform plan -out=tfplan || handle_error "Terraform plan failed"
  
  remove_tf_locks
  
  log_info "Running terraform apply..."
  terraform apply -auto-approve tfplan || handle_error "Terraform apply failed"
  
  log_success "Terraform operations completed successfully"
}

# Main execution
main() {
  log_info "Starting Terraform deployment"
  
  check_aws_cli
  install_dependencies
  run_terraform
  
  log_success "Terraform deployment completed successfully"
  exit 0
}

main