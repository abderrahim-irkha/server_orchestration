## Generate the Key Pair for SSH access to the EC2 instances
# 1. Generate a secure private key
resource "tls_private_key" "generated_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# 2. Save the private key to your local machine (chmod 400 is required for SSH)
resource "local_file" "ssh_key" {
  filename        = "${path.module}/../../../sample-app.key"
  content         = tls_private_key.generated_key.private_key_pem
  file_permission = "0400"
}

# 3. Register the public key with AWS
resource "aws_key_pair" "deployer" {
  key_name   = "sample-app"
  public_key = tls_private_key.generated_key.public_key_openssh
}