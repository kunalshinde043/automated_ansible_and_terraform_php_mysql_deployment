# 3-Tier PHP Application Deployment on AWS using Terraform and Ansible

This project demonstrates a production-style 3-tier architecture deployed on AWS using modern DevOps best practices.

The implementation showcases end-to-end automation where:

* Terraform provisions the complete cloud infrastructure
* Ansible performs configuration management using role-based automation
* The entire workflow runs without manual intervention from infrastructure creation to application availability

---

## Project Highlights

* Infrastructure as Code using Terraform
* Configuration as Code using Ansible roles
* Fully automated Ansible inventory generation
* Secure networking with public and private subnets
* SSH jump-host (bastion) pattern
* Nginx reverse proxy running on a custom port (81)
* Remote Terraform state stored in Amazon S3
* Clean, scalable, industry-aligned DevOps workflow

---

## Architecture Overview

The application follows a standard 3-tier architecture.

### Proxy Layer (Public Subnet)

* Nginx reverse proxy
* Listens on port 81
* Exposes the application to the internet
* Assigned a public IP
* Also acts as an SSH jump (bastion) host

### Application Layer (Private Subnet)

* Nginx with PHP and PHP-FPM
* Hosts the PHP application
* Accessible only through the proxy layer

### Database Layer (Private Subnet)

* MariaDB server
* Stores application data
* No public access

---

## Request Flow

```
User
  |
  |  http://<PROXY_PUBLIC_IP>:81
  |
Nginx Reverse Proxy (Public Subnet)
  |
Application Server (Private Subnet)
  |
MariaDB Server (Private Subnet)
```

---

## Technologies Used

| Category                 | Tools         |
| ------------------------ | ------------- |
| Cloud Provider           | AWS           |
| Infrastructure as Code   | Terraform     |
| Configuration Management | Ansible       |
| Web Server               | Nginx         |
| Backend                  | PHP (PHP-FPM) |
| Database                 | MariaDB       |
| Operating System         | Amazon Linux  |
| State Backend            | Amazon S3     |

---

## Project Structure

```
.
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── ansible/
│   ├── inventory.ini        # auto-generated
│   ├── playbook.yml
│   └── roles/
│       ├── proxy/
│       ├── app/
│       └── db/
│
├── images/
│   └── architecture and verification screenshots
│
└── README.md
```

---

## Infrastructure Provisioning (Terraform)

Terraform provisions the complete AWS infrastructure, including:

* Custom VPC (10.0.0.0/16)
* One public subnet
* Two private subnets
* Internet Gateway
* NAT Gateway
* Route tables and subnet associations
* Security groups
* EC2 instances:

  * Proxy server
  * Application server
  * Database server
* Remote Terraform backend using Amazon S3

---

### Terraform Remote Backend Configuration

```
terraform {
  backend "s3" {
    bucket = "bucket-name"
    key    = "terraform.tf"
    region = "us-west-1"
  }
}
```

---

### Terraform Commands

```
terraform init
terraform validate
terraform plan
terraform apply
```

---

## Security Group Rules

Only required traffic is allowed.

| Port | Purpose                |
| ---- | ---------------------- |
| 22   | SSH                    |
| 81   | Public access to proxy |
| 80   | Internal HTTP traffic  |
| 3306 | MariaDB                |

Note:
The proxy server intentionally listens on port 81 instead of the default HTTP port.

---

## Configuration Management (Ansible)

### Initial Implementation

* The project initially used a single Ansible playbook to configure all tiers.

### Final Implementation (Role-Based)

* The configuration was refactored into Ansible roles to improve scalability and maintainability.

---

### Proxy Role

* Installs Nginx
* Configures reverse proxy
* Listens on port 81
* Forwards traffic to the application server

### Application Role

* Installs Nginx, PHP, and PHP-FPM
* Deploys the PHP application
* Connects to the MariaDB database

### Database Role

* Installs MariaDB
* Creates database and user
* Enables remote database access
* Uses PyMySQL for Ansible database modules

---

## Automated Inventory Generation (Terraform to Ansible)

Manual inventory management was removed to enable full automation.

Terraform dynamically generates the Ansible inventory file using:

* EC2 public and private IPs
* Inventory templates
* Local file rendering

This ensures:

* No hardcoded IP addresses
* Inventory is always synchronized with infrastructure
* No manual post-provisioning steps

---

## SSH Jump Host Pattern

* The proxy server also functions as an SSH jump host
* Application and database servers do not have public IPs
* Ansible uses ProxyCommand to securely access private instances
* SSH keys remain on the control node

Example configuration:

```
ansible_ssh_common_args=-o ProxyCommand="ssh -i key.pem -W %h:%p ec2-user@<proxy_public_ip>"
```

---

## Fully Automated End-to-End Workflow

Terraform automatically triggers Ansible after infrastructure provisioning.

```
terraform apply
      |
      ├─ Provision AWS infrastructure
      ├─ Extract public and private IP addresses
      ├─ Generate Ansible inventory dynamically
      ├─ Execute Ansible playbooks
      |
      └─ Application becomes accessible on port 81
```

---

## Verification

* Application is accessible at:

  ```
  http://<PROXY_PUBLIC_IP>:81
  ```
* Data is successfully inserted and retrieved from MariaDB
* Database access is verified from the private network
* Screenshots are available in the images directory

---

## Key DevOps Concepts Demonstrated

* Infrastructure as Code
* Configuration as Code
* Dynamic configuration generation
* Secure network segmentation
* SSH jump-host pattern
* Role-based automation
* Idempotent deployments
* Production-style DevOps workflow

---

## Summary

This project demonstrates a complete end-to-end deployment of a secure 3-tier application on AWS using Terraform and Ansible. It highlights how infrastructure provisioning, configuration management, security, and automation can be combined into a clean, scalable DevOps pipeline that closely mirrors real-world production practices.

---

## Future Improvements

* Replace reverse proxy with an Application Load Balancer
* Introduce Auto Scaling for the application tier
* Migrate database to Amazon RDS
* Use AWS SSM Session Manager to remove SSH key dependency
* Add CI/CD integration using Jenkins or GitHub Actions
