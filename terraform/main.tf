provider "aws" {
  region = "us-east-2"
}

## Retrieve the default VPC and its ID
data "aws_vpc" "default" {
  default = true
}

## Retrieve the key pair that was generated in the key_pair module
data "aws_key_pair" "existing_key" {
  key_name = "sample-app"
}

## Create a security group that permits HTTP, SSH traffic and all outbound traffic for webservers
resource "aws_security_group" "sample_app_sg" {
  name        = "sample_app_sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id
}

# 1. Create an Ingress Rule to allow HTTP traffic on the specified port
resource "aws_vpc_security_group_ingress_rule" "allow_http_webserver" {
  security_group_id = aws_security_group.sample_app_sg.id
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_webserver" {
  security_group_id = aws_security_group.sample_app_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# 2. Create an Egress Rule to allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_webserver" {
  security_group_id = aws_security_group.sample_app_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

## Create a security group that permits HTTP, SSH traffic and all outbound traffic for Nginx Load Balancer
resource "aws_security_group" "nginx_lb_sg" {
  name        = "nginx_lb_sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id
}

# 1. Create an Ingress Rule to allow HTTP traffic on the specified port
resource "aws_vpc_security_group_ingress_rule" "allow_http_nginx" {
  security_group_id = aws_security_group.nginx_lb_sg.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_nginx" {
  security_group_id = aws_security_group.nginx_lb_sg.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# 2. Create an Egress Rule to allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_nginx" {
  security_group_id = aws_security_group.nginx_lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

## Query the AWS AMI Catalog using Data Source
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}


## Create EC2 instances using the queried AMI and the generated key pair
# 1. Create EC2 instances for webservers
resource "aws_instance" "webserver_instance" {
  count                       = var.instance_count
  ami                         = data.aws_ami.amazon_linux.id
  vpc_security_group_ids      = [aws_security_group.sample_app_sg.id]
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = data.aws_key_pair.existing_key.key_name

  tags = {
    Name    = "${var.base_name}_${count.index}"
    Ansible = "${var.base_name}"
  }
}

# 2. Create EC2 instance for Nginx Load Balancer
resource "aws_instance" "nginx_lb_instance" {
  ami                         = data.aws_ami.amazon_linux.id
  vpc_security_group_ids      = [aws_security_group.nginx_lb_sg.id]
  associate_public_ip_address = true
  instance_type               = "t3.micro"
  key_name                    = data.aws_key_pair.existing_key.key_name

  tags = {
    Name    = "nginx_lb"
    Ansible = "nginx_lb"
  }
}