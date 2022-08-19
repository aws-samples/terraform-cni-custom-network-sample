# Create example security group for pod
resource "aws_security_group" "example_sg" {
  name        = "example_sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "allow http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
   # cidr_blocks      = module.vpc.private_subnets_cidr_blocks
    cidr_blocks      = ["10.0.0.0/16"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
