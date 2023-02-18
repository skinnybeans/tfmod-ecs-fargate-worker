locals {
  # Combine internal defined security group with any additional IDs passed into the module
  service_security_group_ids = length(var.service_addition_sg_ids) > 0 ? concat(var.service_addition_sg_ids, [aws_security_group.web_task.id]) : [aws_security_group.web_task.id]
}

##
## Security groups
##
resource "aws_security_group" "web_task" {
  name   = "${var.gen_environment}-${var.task_name}-task"
  vpc_id = var.net_vpc_id

  # ingress {
  #   description = "Deny ingress for worker tasks"
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.gen_environment}-${var.task_name}-task"
  }
}

##
## Cloudwatch log group for task
##
resource "aws_cloudwatch_log_group" "task_logs" {
  name = "${var.gen_environment}/services/${var.task_name}/"

  retention_in_days = 1

  tags = {
    Name = "${var.gen_environment}/services/${var.task_name}/"
  }
}


##
## Task and service set up
##
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.gen_environment}-${var.task_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name        = "${var.gen_environment}-${var.task_name}-container"
      image       = "${var.task_container_image}:${var.task_container_image_tag}"
      essential   = true
      environment = var.task_container_environment
      portMappings = [{
        protocol      = "tcp"
        containerPort = var.task_container_port
        hostPort      = var.task_container_port
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "${var.gen_environment}/services/${var.task_name}/"
          awslogs-stream-prefix = var.task_name
          awslogs-region        = var.gen_region
        }
      }
    }
  ])
  tags = {
    Name = "${var.gen_environment}-${var.task_name}-task"
  }
}

// Task role for the executing app to do things
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.gen_environment}-${var.task_name}-taskRole"
  tags = {
    Name = "${var.gen_environment}-${var.task_name}-taskRole"
  }

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

// Task execution role to allow fargate to pull and start images
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.gen_environment}-${var.task_name}-taskExecutionRole"

  tags = {
    Name = "${var.gen_environment}-${var.task_name}-taskExecutionRole"
  }

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

// Service to run the task
resource "aws_ecs_service" "main" {
  name                               = "${var.gen_environment}-${var.task_name}-service"
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.main.arn
  desired_count                      = var.scaling_min_capacity
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    security_groups  = local.service_security_group_ids
    subnets          = var.net_task_subnet_ids
    assign_public_ip = true
  }

  tags = {
    Name = "${var.gen_environment}-${var.task_name}-service"
  }
}

##
## Autoscaling
##

resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.scaling_max_capacity
  min_capacity       = var.scaling_min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 60
  }
}
