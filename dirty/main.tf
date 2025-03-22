provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

#### Create Security Groups

resource "aws_default_vpc" "default_vpc" { }

resource "aws_security_group" "MyLBSecurityGroup" {
  name        = "MyLBSecurityGroup"
  description = "Allow to LB for http and https"
  vpc_id      = resource.aws_default_vpc.default_vpc.id
  ingress {
    description = "HTTPS ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}

resource "aws_security_group" "MyWebSecurityGroup" {
  name        = "MyWebSecurityGroup"
  description = "Allow to EC2 from LB on http"
  vpc_id      = resource.aws_default_vpc.default_vpc.id
  ingress {
    description = "HTTPS ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [resource.aws_security_group.MyLBSecurityGroup.id]
  }
  ingress {
    description = "SSH ingress"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
 depends_on = [
  resource.aws_security_group.MyLBSecurityGroup
 ]
}

resource "aws_security_group" "MyWorkerSecurityGroup" {
  name        = "MyWorkerSecurityGroup"
  description = "Allow to Worker EC2 SSH access"
  vpc_id      = resource.aws_default_vpc.default_vpc.id
  ingress {
    description = "SSH ingress"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
   from_port   = 0
   to_port     = 0
   protocol    = "-1"
   cidr_blocks = ["0.0.0.0/0"]
 }
}


