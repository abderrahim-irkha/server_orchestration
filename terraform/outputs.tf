output "instance_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.nginx_lb_instance.*.public_ip
}