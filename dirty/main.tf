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
#### Create SQS

resource "aws_sqs_queue" "MySQS" {
  name  = "MySQS"
}
output "MySQS" {
  value = resource.aws_sqs_queue.MySQS.url
}

#### Make sure Default VPC is created

resource "aws_default_vpc" "default_vpc" { }


#### Create Security Groups

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



#### Create Launch templates

### Get AMI ID

data "aws_ami" "AmazonLinux" {
  most_recent      = true
  filter {
    name   = "boot-mode"
    values = ["uefi-preferred"]
  }
  filter {
    name   = "owner-id"
    values = ["137112412989"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "description"
    values = ["Amazon Linux 2023 AMI * x86_64 HVM kernel-*"]
  }
}
#output "ami" {
#  value  = data.aws_ami.AmazonLinux
#}

### Create Roles

#data "aws_iam_role" "MySQSRole" {
#  name = "MySQSRole"
#}
#output "MySQSRole" {
#  value = data.aws_iam_role.MySQSRole
#}

resource "aws_iam_role" "MySQSRole" {
  name = "MySQSRole"
  description = "Allows EC2 instances to call AWS services on your behalf."
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })
}

data "aws_iam_policy" "AmazonSQSFullAccess" {
  name = "AmazonSQSFullAccess"
}

resource "aws_iam_role_policy_attachment" "MySQSRole_attachment" {
  role       = resource.aws_iam_role.MySQSRole.name
  policy_arn = data.aws_iam_policy.AmazonSQSFullAccess.arn
}

resource "aws_iam_instance_profile" "MySQSRole_profile" {
  name = "MySQSRole_profile"
  role = resource.aws_iam_role.MySQSRole.name
}


### Create Launch Templates

resource "aws_launch_template" "MyWebLaunchTemplate" {
  name                 = "MyWebLaunchTemplate"
  image_id             = data.aws_ami.AmazonLinux.id
  instance_type        = "t2.micro"
  key_name             = "myKey"
  security_group_names = [resource.aws_security_group.MyWebSecurityGroup.name]
  iam_instance_profile {
    arn = resource.aws_iam_instance_profile.MySQSRole_profile.arn
  }
  user_data            = base64encode(replace(file("${path.module}/user_data/MyWebUserData.sh"), "<SQS-URL>", resource.aws_sqs_queue.MySQS.url))
}
