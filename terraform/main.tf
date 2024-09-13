#1. Creating frontend ec2-instance
module "frontend" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"

  instance_type          = "t3.micro"
  vpc_security_group_ids = [data.aws_ssm_parameter.frontend_sg_id.value]
  # convert StringList to list and get first element
  subnet_id              = local.public_subnet_id #vpn creates in public subnet
  ami = data.aws_ami.ami_info.id
  
  tags = merge(
    var.common_tags,{
        Name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"#expense-dev-frontend
    }
  )
}

#2. Connect to server using null resource and remote exec
#3. Copy the script into instance
#4. run the ansible configuration
resource "null_resource" "frontend" {
  triggers = {
    instance_id = module.frontend.id #this will be triggered everytime when instance is created
  }
  
  connection { #establishing connection to the server using username,password and host=private ip of the server
        type     = "ssh"
        user     = "ec2-user"
        password = "DevOps321"
        host     = module.frontend.private_ip
  }
  
  provisioner "file" { #this will copy the file from here and paste in the location in server where u specify
        source      = "${var.common_tags.Component}.sh" #frontend.sh
        destination = "/tmp/${var.common_tags.Component}.sh" #placing in tmp location in frontend server
  }
  
  provisioner "remote-exec" { #this will run the .sh script in remote server
        inline = [ #passing the arguments
            "chmod +x /tmp/${var.common_tags.Component}.sh", #giving execute perm for the frontend.sh
            "sudo sh /tmp/${var.common_tags.Component}.sh ${var.common_tags.Component} ${var.environment} ${var.app_version}"
            #giving sudo access and passing frontend as param1 and environment as param2
            #for detailed clairty check frontend.sh file
        ]
  }
}
#5. stop the server
resource "aws_ec2_instance_state" "frontend" {
  instance_id = module.frontend.id
  state       = "stopped"
  # stop the serever only when null resource provisioning is completed
  depends_on = [ null_resource.frontend ] #this should run only when the frontend server is created
}
#6. take the AMI of the server
resource "aws_ami_from_instance" "frontend" {
  name               = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  source_instance_id = module.frontend.id
  depends_on = [ aws_ec2_instance_state.frontend ] #AMI id should be taken only when instance is stopped completely
}
#7.delete the server
#once we take the AMI of the server, we no longer need the server, we can replicate the same server using AMI ID
resource "null_resource" "frontend_delete" {
    triggers = {
      instance_id = module.frontend.id # this will be triggered everytime instance is created
    }

    provisioner "local-exec" {
        command = "aws ec2 terminate-instances --instance-ids ${module.frontend.id}"
    } 

    depends_on = [ aws_ami_from_instance.frontend ]
}
#8. target group creation
resource "aws_lb_target_group" "frontend" {
  #target group tellsm ALB where to forward traffic and helps manage which resource are active & healthy
  name     = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  port     = 80
  protocol = "HTTPS"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  health_check {
    path                = "/" #ALB send req to /. it should send response whether app is working properly
    port                = 80 #frontend runs on port 80
    protocol            = "HTTPS"
    healthy_threshold   = 2 #how many consecutive successful health check responses needed 
    unhealthy_threshold = 2 #how many consectuive failed health checks required for instances to consider unhealthy
    matcher             = "200-299" #https response
  }
}
#launch template contains config for EC2 instances to be launched automatically by an autoscaling groups
resource "aws_launch_template" "frontend" {
  name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"

  image_id = aws_ami_from_instance.frontend.id #frontend instance AMI ID from step6
  instance_initiated_shutdown_behavior = "terminate" #terminate when the instance no longer needed
  instance_type = "t3.micro"
  update_default_version = true # sets the latest version to default

  vpc_security_group_ids = [data.aws_ssm_parameter.frontend_sg_id.value]

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      var.common_tags,
      {
        Name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
      }
    )
  }
}
#9.Autoscaling and Policy
resource "aws_autoscaling_group" "frontend" {
  name                      = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  max_size                  = 5 #AGS will not launch more than 5 no matter the demand
  min_size                  = 1 #AGS ensures at least 1 instance is running, even demand drops, ASG will never terminate all instances and will keep one running
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 1
  target_group_arns = [aws_lb_target_group.frontend.arn] #frontend target group
  #as new instances launched, they will automatically registered with this target group
  launch_template { #specifies LAunch template that auto scaling group will use to launch EC2 instances
    id      = aws_launch_template.frontend.id #launch template id
    version = "$Latest" #latest version
  }
  vpc_zone_identifier       = split(",", data.aws_ssm_parameter.public_subnet_ids.value) #2 private subnet id's

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
    propagate_at_launch = true #ensures tag is automatically applied to any instances launched by this ASG
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Project"
    value               = "${var.project_name}"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_policy" "frontend" {
  name                   = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.frontend.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" #CPU Utlization as metric here for autoscaling policy
    }

    target_value = 10.0
  }
}
#10. listener rule
resource "aws_lb_listener_rule" "frontend" {
  listener_arn = data.aws_ssm_parameter.app_alb_listener_arn_https.value
  priority     = 100 # less number will be first validated

  action {
    type             = "forward" #forward traffic to a target group, when condition is met
    target_group_arn = aws_lb_target_group.frontend.arn #mentioning which target it needs to send, when conditions are met
  }

  condition {
    host_header {
      values = ["web-${var.environment}.${var.zone_name}"] #when url comes with web-dev-abhinavk.fun then 
      #route the traffic to frontend target group
    }
  }
}
