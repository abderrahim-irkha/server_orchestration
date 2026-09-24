# Server Orchestration on AWS cloud provider using Terraform and Ansible IaC tools

This repo contains configuration files leveraging Terraform as a provisionning tool to create a pool of AWS EC2 instances

## SSH Key Pair

The first step is to create SSH key pair that will be used to configure the pool of servers (later using Ansible)

1 - Access the key_pair configuration module
```bash
$cd modules/key_pair
```

2 - To initilize the projecta and download the corresponding provider plugins from the Terraform Registry, run
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

NB: --auto-approve argument used to automatically approve the configuration without interaction