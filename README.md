# Deploy a sample Node.js application using Server Orchestration on AWS with Terraform and Ansible as IaC tools.

This repo contains configuration files leveraging Terraform as a provisioning tool to create a pool of AWS EC2 instances and configure the infrastructure using Ansible as a Configuration Management tool

## Authenticate to AWS

Prerequisites:
An Access Key ID and a Secret Access Key generated from the AWS IAM Console under Users -> [Your Username] -> Security credentials -> Create access key

1 - Open your terminal and run:
```bash
$aws configure
```

2 - Provide the following inputs when prompted:
- AWS Access Key ID: Paste your access key.
- AWS Secret Access Key: Paste your secret key.
- Default region name: Enter your target region (e.g., us-east-2, as this project will provision all the infrastructure in this region).
- Default output format: Type json (or leave blank)

For more information, check the AWS documentation: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

## Provision SSH Key Pair

The first step is to create an SSH key pair that will be used to configure the pool of servers (later using Ansible)

This module does the following:

* Generate a secure private key
* Save the private key to your local machine (chmod 400 is required for SSH)
* Register the public key with AWS

1 - Access the key_pair configuration module
```bash
$cd modules/key_pair
```

2 - To initialize the project and download the corresponding provider plugins from the Terraform Registry, run
```bash
$terraform init
```

3 - To get an idea of what is going to be created, run
```bash
$terraform plan
```

4 - To provision the key pair, run
```bash
$terraform apply --auto-approve
```

NB: The --auto-approve argument is used to approve the configuration automatically without interaction

## Provision the infrastructure using Terraform

This Terraform project does the following:

* Retrieve the default VPC and its ID
* Retrieve the key pair that was generated in the key_pair module
* Create a security group that permits HTTP and SSH traffic and all outbound traffic for webservers
* Create a security group that permits HTTP and SSH traffic and all outbound traffic for the Nginx Load Balancer
* Query the AWS AMI Catalog using Data Source
* Create EC2 instances using the queried AMI and the generated key pair
  * A # of instances will be created as web servers
  * A single EC2 instance to act as an Nginx load balancer, which receives requests on port 80 and forwards the traffic to the pool of servers that listen on port 8080

To provision the infrastructure, run the following commands:

1 - Change to the terraform directory that contains the configuration files
```bash
$cd terraform/
```

2 - To initialize the project and download the corresponding provider plugins from the Terraform Registry, run
```bash
$terraform init
```

3 - To get an idea of what is going to be created, run
```bash
$terraform plan --var-file="webserver.tfvars"
```
NB: We pass the variable file as it contains the number of instances and the base name for resources:
```yml
base_name = "sample_app"
instance_count = 3
```

4 - To provision the infrastructure, run
```bash
$terraform apply --auto-approve
```
5 - Make sure to copy the public IP address of your EC2 instance that will run your load balancer, as it will be displayed as an output variable
