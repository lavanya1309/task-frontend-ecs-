provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-sg"
  description = "Allow HTTP, SSH, and custom ports"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow port 5000"
    from_port   = 5000
    to_port     = 5000
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

resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-cluster"
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.app_name}-ecs-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_attach" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.app_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name
}

resource "aws_launch_template" "ecs_lt" {
  name_prefix   = "${var.app_name}-lt"
  image_id      = "ami-0e001c9271cf7f3b9" # Amazon ECS-optimized Amazon Linux 2 (change as needed)
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${var.app_name}-cluster >> /etc/ecs/ecs.config
            EOF
  )

  vpc_security_group_ids = [aws_security_group.ecs_sg.id]
}

resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix          = "${var.app_name}-asg"
  max_size             = 1
  min_size             = 1
  desired_capacity     = 1
  launch_template {
    id      = aws_launch_template.ecs_lt.id
    version = "$Latest"
  }
  vpc_zone_identifier = data.aws_subnets.default.ids
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-task"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = var.app_name
    image     = var.docker_image
    essential = true
    portMappings = [
      { containerPort = 3000, hostPort = 80 }
      
    ]
  }])
}

resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "EC2"
}
