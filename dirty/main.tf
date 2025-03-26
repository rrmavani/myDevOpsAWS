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

### Create Roles

resource "aws_iam_role" "MyWebRole" {
  name = "MyWebRole"
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

resource "aws_iam_role" "MyWorkerRole" {
  name = "MyWorkerRole"
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

data "aws_iam_policy" "CloudWatchFullAccess" {
  name = "CloudWatchFullAccessV2"
}

resource "aws_iam_role_policy_attachment" "MyWebRole_SQS_attachment" {
  role       = resource.aws_iam_role.MyWebRole.name
  policy_arn = data.aws_iam_policy.AmazonSQSFullAccess.arn
}

resource "aws_iam_role_policy_attachment" "MyWorkerRole_CloudWatch_attachment" {
  role       = resource.aws_iam_role.MyWorkerRole.name
  policy_arn = data.aws_iam_policy.CloudWatchFullAccess.arn
}

resource "aws_iam_role_policy_attachment" "MyWorkerRole_SQS_attachment" {
  role       = resource.aws_iam_role.MyWorkerRole.name
  policy_arn = data.aws_iam_policy.AmazonSQSFullAccess.arn
}

resource "aws_iam_instance_profile" "MyWebRole_profile" {
  name = "MyWebRole_profile"
  role = resource.aws_iam_role.MyWebRole.name
}

resource "aws_iam_instance_profile" "MyWorkerRole_profile" {
  name = "MyWorkerRole_profile"
  role = resource.aws_iam_role.MyWorkerRole.name
}

### Create Launch Templates

resource "aws_launch_template" "MyWebLaunchTemplate" {
  name                 = "MyWebLaunchTemplate"
  update_default_version = true
  image_id             = data.aws_ami.AmazonLinux.id
  instance_type        = "t2.micro"
  key_name             = "myKey"
  vpc_security_group_ids   = [resource.aws_security_group.MyWebSecurityGroup.id]
  iam_instance_profile {
    arn = resource.aws_iam_instance_profile.MyWebRole_profile.arn
  }
  user_data            = base64encode(replace(file("${path.module}/user_data/MyWebUserData.sh"), "<SQS-URL>", resource.aws_sqs_queue.MySQS.url))
}

resource "aws_launch_template" "MyWorkerLaunchTemplate" {
  name                 = "MyWorkerLaunchTemplate"
  update_default_version = true
  image_id             = data.aws_ami.AmazonLinux.id
  instance_type        = "t2.micro"
  key_name             = "myKey"
  vpc_security_group_ids   = [resource.aws_security_group.MyWorkerSecurityGroup.id]
  iam_instance_profile {
    arn = resource.aws_iam_instance_profile.MyWorkerRole_profile.arn
  }
  user_data            = base64encode(replace(file("${path.module}/user_data/MyWorkerUserData.sh"), "<SQS-URL>", resource.aws_sqs_queue.MySQS.url))
}

#### Create MyWebTargetGroup
resource "aws_lb_target_group" "MyWebTargetGroup" {
  name     = "MyWebTargetGroup"
  port     = 80
  protocol = "HTTP"
  target_type = "instance"
  vpc_id   = resource.aws_default_vpc.default_vpc.id
}


#### Create Load Balancer

data "aws_subnets" "default_vpc_subnet" {
  filter {
    name   = "vpc-id"
    values = [resource.aws_default_vpc.default_vpc.id]
  }
}

resource "aws_lb" "MyWebLoadBalancer" {
  name               = "MyWebLoadBalancer"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  subnets            = data.aws_subnets.default_vpc_subnet.ids  
  security_groups    = [resource.aws_security_group.MyLBSecurityGroup.id]
}

resource "aws_lb_listener" "MyWebLoadBalancer_Listener" {
  load_balancer_arn = resource.aws_lb.MyWebLoadBalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.MyWebTargetGroup.arn
  }
}

#### Create Auto Scalling Groups
data "aws_availability_zones" "available" {}

resource "aws_autoscaling_group" "MyWebAutoScalingGroup" {
  name               = "MyWebAutoScalingGroup"
  availability_zones = data.aws_availability_zones.available.names
  desired_capacity   = 1
  max_size           = 4
  min_size           = 1

  launch_template {
    id      = aws_launch_template.MyWebLaunchTemplate.id
    version = aws_launch_template.MyWebLaunchTemplate.latest_version
  }

  target_group_arns = [resource.aws_lb_target_group.MyWebTargetGroup.arn]
}

resource "aws_autoscaling_group" "MyWorkerAutoScalingGroup" {
  name               = "MyWorkerAutoScalingGroup"
  availability_zones = data.aws_availability_zones.available.names
  desired_capacity   = 1
  max_size           = 3
  min_size           = 1

  launch_template {
    id      = aws_launch_template.MyWorkerLaunchTemplate.id
    version = aws_launch_template.MyWorkerLaunchTemplate.latest_version
  }

  instance_refresh {
    strategy    = "Rolling"
    triggers    = ["launch_template"]
  }
}

output "MyWebLoadBalancer" {
  value = resource.aws_lb.MyWebLoadBalancer.dns_name
}

