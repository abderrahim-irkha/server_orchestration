# Deploy a sample Node.js application using Server Orchestration on AWS with Terraform and Ansible as IaC tools.

This repository provides a production-ready Infrastructure as Code (IaC) framework for deploying a sample Node.js application on AWS using an automated Server Orchestration approach. By leveraging the combined power of Terraform for provisioning AWS infrastructure and Ansible for configuration management, the deployment pipeline fully supports zero-downtime rolling updates to ensure continuous service availability.

## Authenticate to AWS

Prerequisites:
An Access Key ID and a Secret Access Key are generated from the AWS IAM Console under Users -> [Your Username] -> Security credentials -> Create access key

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

#### This module does the following:

* Generate a secure private key
* Save the private key to your local machine (chmod 400 is required for SSH)
* Register the public key with AWS

1 - Access the key_pair configuration module
```bash
$cd terraform/modules/key_pair
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

#### This Terraform project does the following:

* Retrieve the default VPC and its ID
* Retrieve the key pair that was generated in the key_pair module
* Create a security group that permits HTTP (port 8080) and SSH (port 22) traffic and all outbound traffic for webservers
* Create a security group that permits HTTP (port 80) and SSH (port 22) traffic and all outbound traffic for the Nginx Load Balancer
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

## Configure the pool of servers to run the Node.js sample app using Ansible

The file ansible/configure_sample-app_playbook.yml is responsible for configuring the webservers.

```yml
---
- name: Configure the servers to run the sample-app
  hosts: sample_app    #1
  gather_facts: true
  become: true

  roles:
    - role: nodejs-app    #2
    - role: sample-app    #3
      become_user: app-user    #4
```

#### This Ansible Playbook does the following:

1. Target "sample_app" instances
2. The code in this configuration file uses two roles. The first role, called "nodejs-app", is responsible for configuring a server to run Node.js apps
3. The second role is called sample-app, and it’s responsible for running the sample app
4. The "sample-app" role will be executed as the OS user "app-user", which is a user that the "nodejs-app" role creates, rather
than as the root user

The nodejs-app role tasks config file: ansible/roles/nodejs-app/tasks/main.yml. This role is fairly generic, usable with almost any Node.js app:

* Install Node.js on the webservers EC2 instances.
* Create a new OS user called app-user. This allows you to run your apps with a user with more limited permissions than root.
* Install PM2 and configure it to run on boot. You’ll see what PM2 is
shortly.

The sample-app role contains two folders, files, and tasks:

```text
    .
├── nodejs-app
│   └── tasks
│       └── main.yml
└── sample-app
    ├── files
    │   ├── app.config.js
    │   └── app.js
    └── tasks
        └── main.yml
```
### Node.js sample app

app.js is the sample Node.js app that prints "Hello, World!" as output

```javascript
const http = require('http');

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Hello, World!\n');          
});

const port = process.env.PORT || 8080; 
server.listen(port,() => {
  console.log(`Listening on port ${port}`);
});
```

app.config.js is a file that contains PM2 configuration. PM2 is a process supervisor, which is a tool you can use to run your apps, monitor them, restart them after a reboot or a crash, and manage their logging. Process supervisors provide one layer of auto-healing for long-running apps.

Many process supervisors exist, including PM2 Supervisor and Systemd, with Systemd being the one you’re likely to use, as it’s built into most Linux distributions these days. PM2 was picked for this project because it has features designed specifically for Node.js apps.

```javascript
module.exports = {
  apps : [{
    name   : "sample-app",
    script : "./app.js",       #1
    exec_mode: "cluster",      #2
    instances: "max",
    env: {
      "NODE_ENV": "production" #3
    }
  }]
}
```

#### This file configures PM2 to do the following:

1. Run app.js to start the app.
2. Run in cluster mode, so that instead of a single Node.js process, you get one process per CPU, ensuring that your app uses all the CPUs on your server.
3. Set the NODE_ENV environment variable to production, which tells Node.js apps and plugins to run in production mode.

Finally, we configure the "sample-app" role task to run the sample app. Config file: ansible/roles/sample-app/tasks/main.yml

```yml
- name: Copy sample app                   #1       
  copy:
    src: ./
    dest: /home/app-user/sample-app

- name: Start sample app using pm2        #2       
  shell: pm2 start app.config.js
  args:
    chdir: /home/app-user/sample-app

- name: Save pm2 app list so it survives reboot  #3
  shell: pm2 save
```

#### The preceding code does the following:

1. Copy the code in the files folder (app.js, app.config.js) to the server.
2. Use PM2 to start the app in the background and start monitoring it.
3. Save the list of apps PM2 is running so that if the server reboots, PM2 will automatically restart those apps.

### Dynamic Ansible Inventory:

Since we run servers in the cloud, where servers come and go often and IP addresses change frequently, we’re better off using an inventory plugin that can dynamically discover our servers. For example, we can use the aws_ec2 inventory plugin to discover the EC2 instances we deploy with Terraform. Config file: ansible/inventory.aws_ec2.yml

```yml
plugin: amazon.aws.aws_ec2
regions:
- us-east-2
keyed_groups:
- key: tags.Ansible    #1
leading_separator: ''  #2
```
This config file does the following:

1. During the provisioning of our infrastructure using Terraform, we assigned an "Ansible" tag. In the preceding section, we set this tag to sample_app when we passed the var.base_name. So, that will be the name of the group.
2. By default, Ansible adds a leading underscore to group names. This disables it so the group name matches the tag name.

### Group variables:

For each group in your inventory, you can specify group variables to configure how to connect to the servers in that group. You define these variables in YAML files in the group_vars folder, with the name of the file set to the name of the group. For example, for the EC2 instance in the sample_app group, we created a file in group_vars/sample_app.yml

```yml
ansible_user: ec2-user                           #1
ansible_ssh_private_key_file: ../sample-app.key  #2
ansible_host_key_checking: false                 #3
```
#### The preceding code does the following:

1. Use ec2-user as the username to connect to the EC2 instance. This is the username you need to use with Amazon Linux AMIs.
2. Use the SSH private key sample-app.key to authenticate to the EC2 instances. This is the key we provisioned earlier using Terraform
3. Skip host key checking so you don’t get interactive prompts from Ansible.

#### To try this Ansible Playbook, run the following command:

```bash
$ansible-playbook -v -i inventory.aws_ec2.yml configure_sample-app_playbook.yml
```

Ansible will discover our servers and, on each one, install Node.js and run the sample app. At the end, you should see the IP addresses of the servers

Wait a few minutes for everything to deploy, and in the end, you should see log output that looks like this:

```text
PLAY RECAP *****************************************************************************************************************************
xxx.us-east-2.compute.amazonaws.com : ok=9    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
xxx.us-east-2.compute.amazonaws.com : ok=9    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
xxx.us-east-2.compute.amazonaws.com : ok=9    changed=8    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

Copy the IP of one of the three servers, open http://<IP>:8080 in your web browser, and you should see the familiar “Hello, World!” text

While three servers are great for redundancy, it’s not so great for usability, as your users typically want just a single endpoint to hit. This requires deploying a load balancer

## Configure the Load Balancer we deployed earlier using Ansible and Nginx

### Defining the Nginx Load Balancer group vars

We copied the same configuration to the group_vars file named nginx_lb, which is defined as a tag name during the provisioning phase

### Specify the nginx role as a dependency

Now you can configure these servers to run Nginx by using an Ansible role called nginx that’s available in the GitHub repo https://github.com/abderrahim-irkha/nginx-role

NB: Forked from brikis98/devops-book-nginx-role

To use the nginx role, we created a file called requirements.yml

```yml
- name: nginx
  src: https://github.com/abderrahim-irkha/nginx-role
  version: 1.0.0
```

Next, run the ansible-galaxy command to install the role:

```bash
$ansible-galaxy role install -r requirements.yml
```

### Configure Nginx

Config file: ansible/configure_nginx_playbook.yml

```yml
- name: Configure servers to run nginx
  hosts: nginx_lb                                #1
  gather_facts: true
  become: true
  roles:
    - role: nginx                                #2
      vars:                                      #3
        servers: >-
          {{ groups['sample_app']
             | map('extract', hostvars, 'private_dns_name')
             | map('regex_replace', '$', ':8080')
             | list }}
```

#### This playbook does the following:

1. Targets the nginx_lb group we configured in our inventory.
2. Configures the servers in that group, using the nginx role we just installed.
3. Uses Jinja template syntax to set the servers input variable to the private IP address and port 8080 of each of our sample app servers.

#### To try this Ansible Playbook, run the following command:

```bash
$ansible-playbook -v -i inventory.aws_ec2.yml configure_nginx_playbook.yml
```

Wait a few minutes for everything to deploy, and in the end, you should see log output that looks like this:

```text
PLAY RECAP *****************************************************************************************************************************
xxx.us-east-2.compute.amazonaws.com : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0  
```

The value on the left, xxx.us-east-2.compute.amazonaws.com, is a domain name you can use to access the nginx server. If you open http://xxx.us-east-2.compute.amazonaws.com in your browser (this time with no port number, as nginx is listening on port 80, the default port for HTTP), you should see “Hello, World!” yet again. Each time you refresh the page, Nginx will send that request to a different EC2 instance (known as round-robin load balancing). Congrats, you now have a single endpoint you can give your users, and that endpoint will automatically balance the load across multiple servers!

## Roll Out Updates with Ansible

So you’ve now seen how to deploy using a server orchestration tool, but what about doing an update? The same configuration file from the playbook ansible/configure_sample-app_playbook.yml can be adjusted to do a rolling deployment

### Rolling deployment:

```yml
---
- name: Configure the servers to run the sample-app

  # ... (Other params omitted for clarity) ...

  serial: 1                #1
  max_fail_percentage: 30  #2
```

1. Setting "serial" to "1" tells Ansible to apply changes to one server at a time. Since we have three servers total, this ensures that two servers are always available to serve the traffic while one goes down briefly for an update.
2. The "max_fail_percentage" parameter tells Ansible to abort a deployment if more than this percentage of servers hit an error during the upgrade. Setting this to 30% with three servers means that Ansible will abort the deployment if even a single server hits an error, so we never lose more than one server to a broken update

NB: This configuration is already included in this repo; to activate this feature, you can just uncomment these parameters within the file

Let’s give the rolling deployment a shot. Update the text that the app responds with in app.js

### Update the app response text (ansible/roles/sample-app/files/app.js)

```javascript
res.end('Fundamentals of DevOps!\n');
```

And rerun the playbook:

```bash
$ansible-playbook -v -i inventory.aws_ec2.yml configure_sample-app_playbook.yml
```

Ansible will roll out the change to one server at a time. When it’s done, if you refresh the Nginx IP in your browser, you should see the text “Fundamentals of DevOps!”

Or you can see the change live from another terminal by running this command:

```bash
$while true; do curl http://<YourLoadBalancer-IP>; done
```

So, during the deployment, the Nginx Load Balancer will keep forwarding the traffic to each web server at a time, following the approach of Round Robin. So, the output will toggle between "Hello, World!" and "Fundamentals of DevOps!" until the upgrade is finished for all the servers
