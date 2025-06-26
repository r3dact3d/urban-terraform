# Resource file 

terraform {
  required_providers {
    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

terraform {
  backend "s3" {
    bucket = "tfstate-bucket-blinker21"
    key    = "terraform.tfstate"
    region = "us-east-2"
  }
}

provider "aws" {
  region = "us-east-2"
}

# Add key for ssh connection
resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0YP818L8HTt+pKUU+XPD8dJ9kYDhtplUKaodICGcS63A6EgdGGaxh45DVz8JmTNbP3RHQw6XbfTjNGmOO56UaGxQOsc+ONZ8fFjd+qa+7hBo6tIlrdRkrgZgKNDhTh4HijDgaqpPLhXroUK2TE61CSCiJezVbwwXtXU43wQYoeR06E+Ji1lfLLb5b5pIuUKwTRwa+6u9zL7JrDznKq5YZxsmkX3PNI9gHQT+SnSqPOGctXhbMQX7JWZA60EFx8MZXe8O9QC3LMrgNv90CCR9qnyd7/WTtb+lk/7lTYbFfj2W0WsQZMc2tnvoNv8azeCQcSHs6U2nsKd7lxXmmD0OFtXxSqI/O1628Q71sFjPIvET04I9ENHaAWwaI3s98I3Lt8Z5NLNqHrxwhmrFT5mTdn91Fzq4Ax7UKqcVG8Rtkzg7HnXL6nLIQs/cdRprysJIGC0aEpoHSN1OTqMcJkP4ySv5aYgT/G68Uau5JkBS8tKbeKNw+KE4Aq6tUJ+3etYc= brthomps@brthomps-thinkpadx1carbongen9.remote.csb"
}

resource "aws_vpc" "exposed_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = "true"
  instance_tenancy     = "default"

  tags = {
    Name      = "Exposed_VPC"
    Terraform = "true"
  }
}

resource "aws_internet_gateway" "exposed_igw" {
  vpc_id = aws_vpc.exposed_vpc.id

  tags = {
    Name      = "EXPOSED_IGW"
    Terraform = "true"
  }
}

resource "aws_route_table" "exposed_pub_igw" {
  vpc_id = aws_vpc.exposed_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.exposed_igw.id
  }

  tags = {
    Name      = "Exposed-RouteTable"
    Terraform = "true"
  }
}

resource "aws_subnet" "exposed_subnet" {
  availability_zone       = "us-east-2a"
  cidr_block              = "10.1.0.0/24"
  map_public_ip_on_launch = "true"
  vpc_id                  = aws_vpc.exposed_vpc.id

  tags = {
    Name      = "Exposed-Subnet"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "exposed_rt_subnet_public" {
  subnet_id      = aws_subnet.exposed_subnet.id
  route_table_id = aws_route_table.exposed_pub_igw.id
}

resource "aws_security_group" "exposed_security_group" {
  name        = "exposed-sg"
  description = "Security Group for exposed webserver"
  vpc_id      = aws_vpc.exposed_vpc.id

  tags = {
    Name      = "Exposed-Security-Group"
    Terraform = "true"
  }
}

resource "aws_security_group_rule" "http_ingress_access" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.exposed_security_group.id
}

resource "aws_security_group_rule" "ssh_ingress_access" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.exposed_security_group.id
}

resource "aws_security_group_rule" "postgresql_ingress_access" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.exposed_security_group.id
}

resource "aws_security_group_rule" "https_ingress_access" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.exposed_security_group.id
}

resource "aws_security_group_rule" "egress_access" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.exposed_security_group.id
}

# Set ami for ec2 instance
data "aws_ami" "fedora" {
  most_recent = true
  filter {
    name   = "name"
    values = ["fedora-coreos-42.2025*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["125523088429"]
}

resource "aws_instance" "exposed_instance" {
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.exposed_security_group.id]
  associate_public_ip_address = true
  key_name        = aws_key_pair.my_key.key_name
  user_data                   = file("user_data.txt")
  ami                         = data.aws_ami.fedora.id
  availability_zone           = "us-east-2a"
  subnet_id                   = aws_subnet.exposed_subnet.id

# Specify the root block device to adjust volume size
  root_block_device {
    volume_size = 40        # Set desired size in GB (e.g., 100 GB)
    volume_type = "gp3"      # Optional: Specify volume type (e.g., "gp3" for general purpose SSD)
    delete_on_termination = true  # Optional: Automatically delete volume on instance termination
  }
  
  tags = {
    Name      = "Exposed-Node"
    Terraform = "true"
  }
}

# Add created ec2 instance to ansible inventory
resource "ansible_host" "exposed_instance" {
  name   = aws_instance.exposed_instance.public_dns
  groups = ["webserver"]
  variables = {
    ansible_user                 = "ec2-user",
    ansible_ssh_private_key_file = "~/.ssh/id_rsa",
    ansible_python_interpreter   = "/usr/bin/python3",
  }
}