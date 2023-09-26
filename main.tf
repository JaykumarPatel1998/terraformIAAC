terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
}

variable "vpc_cidr" {
  description = "value for vpc cidr block"
}

variable "public_subnet_cidr" {
  description = "value for public subnet cidr block"
}

variable "private_subnet_cidr" {
  description = "value for private subnet cidr block"
}

#provisioning a vpc in aws with subnet
resource "aws_vpc" "public_vpc" {
  cidr_block = var.vpc_cidr
  instance_tenancy = "default"
  tags = {
    name = "development"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.public_vpc.id
  cidr_block = var.public_subnet_cidr
  availability_zone = "us-east-1a"
  tags = {
    name = "development",
    subnet = "10.0.2.0/24",
    access = "public"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.public_vpc.id
  cidr_block = var.private_subnet_cidr
  availability_zone = "us-east-1b"
  tags = {
    name = "development",
    subnet = "10.0.1.0/24",
    access = "private"
  }
}

# creating internet gateway so our vpc can access the internet
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.public_vpc.id
}

# what route table does is routes the traffic ingress/egress inbound/outbound to destined ip address
resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.public_vpc.id

  # IPV4 ROUTE TABLE
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }

  # IPV6 ROUTE TABLE
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.ig.id
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.prod_route_table.id
}

# create security group to allow traffic from internet
resource "aws_security_group" "allow_ssh_https_http_from_internet" {
  name = "allow_ssh_https_http_from_internet"
  description = "allow_ssh_https_http_from_internet"
  vpc_id = aws_vpc.public_vpc.id

  ingress {
    description      = "https from internet"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "http from internet"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "ssh from internet"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}


# create security group to allow traffic from any resource within vpc
resource "aws_security_group" "allow_ssh_https_http_from_resource_in_vpc" {
  name = "allow_ssh_https_http_from_resource_in_vpc"
  description = "allow_ssh_https_http_from_resource_in_vpc"
  vpc_id = aws_vpc.public_vpc.id

  ingress {
    description      = "https from any resource with in vpc"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.public_vpc.cidr_block]
  }

  ingress {
    description      = "http from any resource with in vpc"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.public_vpc.cidr_block]
  }

  ingress {
    description      = "ssh from any resource with in vpc"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.public_vpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [aws_vpc.public_vpc.cidr_block]
  }
}

# now we need to create network interface of the ec2 instance we are going to connect, basically it can be any ip in the public subnet
# basically creating an instance network interface card but we can only recognize instance in the private network
# we added an actual host to our public subnet
resource "aws_network_interface" "public_instance_network_interface_card" {
  subnet_id = aws_subnet.public_subnet.id
  private_ips = ["10.0.2.50"]
  security_groups = [aws_security_group.allow_ssh_https_http_from_internet.id]
}

# now we need to assign a public ip to our nic so that internet can identify it ip and let you connect to your application which is hosted on ec2 instance
resource "aws_eip" "public_ip" {
  network_interface = aws_network_interface.public_instance_network_interface_card.id
  vpc = true
  associate_with_private_ip = "10.0.2.50"

  depends_on = [ aws_internet_gateway.ig ]
}

# provisioning a basic ec2 instance on aws and install/enable apache2 
resource "aws_instance" "internet_facing_instance" {
  ami = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "terraform"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.public_instance_network_interface_card.id
  }

  user_data = <<-EOF
#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl start apache2
sudo bash -c 'echo your very first web server > /var/www/html/index.html'
EOF

  tags = {
    Name = "internet_facing_instance_terraform"
    "private-ip" = "10.0.2.50"
  }
}




# now we need to create network interface of the private ec2 instance we are going to connect using public ec2 instance, basically it can be any ip in the private subnet
# basically creating an instance network interface card but we can only recognize instance in the private network
# we added an actual host to our private subnet
resource "aws_network_interface" "private_instance_network_interface_card" {
  subnet_id = aws_subnet.private_subnet.id
  private_ips = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_ssh_https_http_from_resource_in_vpc.id]
}

# provisioning a basic ec2 instance on aws and install/enable apache2 
resource "aws_instance" "private_instance" {
  ami = "ami-0261755bbcb8c4a84"
  instance_type = "t2.micro"
  availability_zone = "us-east-1b"
  key_name = "terraform"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.private_instance_network_interface_card.id
  }

  user_data = <<-EOF
#!/bin/bash
sudo apt update -y
sudo apt install apache2 -y
sudo systemctl start apache2
sudo bash -c 'echo your very first web server > /var/www/html/index.html'
EOF

  tags = {
    Name = "private_instance_terraform"
    "private-ip" = "10.0.1.50"
  }
}

output "public_server_ip" {
  value = aws_eip.public_ip.public_ip
}
