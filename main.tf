# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}
# Create a VPC
resource "aws_vpc" "mz" {
  cidr_block = "10.0.0.0/16"
  tags = {
      Name = "mz-vpc"
    }

}
#Creating Public Subnets
resource "aws_subnet" "mz-subnet1"{
    vpc_id = aws_vpc.mz.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-2a"
    tags = {
      Name = "mz-subnet1"
    }
}
resource "aws_subnet" "mz-subnet2"{
    vpc_id = aws_vpc.mz.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "us-east-2b"
    tags = {
      Name = "mz-subnet2"
    }
}

#Creating Privates Subnets
resource "aws_subnet" "mz-privatesubnet1"{
    vpc_id = aws_vpc.mz.id
    cidr_block = "10.0.10.0/24"
    availability_zone = "us-east-2a"
    tags = {
      Name = "mz-privatesubnet1"
    }
}
resource "aws_subnet" "mz-privatesubnet2"{
    vpc_id = aws_vpc.mz.id
    cidr_block = "10.0.11.0/24"
    availability_zone = "us-east-2b"
    tags = {
      Name = "mz-privatesubnet2"
    }
}
resource "aws_subnet" "mz-databasesubnet1"{
    vpc_id = aws_vpc.mz.id
    cidr_block = "10.0.20.0/24"
    availability_zone = "us-east-2a"
    tags = {
      Name = "mz-databasesubnet1"
    }
}
resource "aws_subnet" "mz-databasesubnet2"{
    vpc_id = aws_vpc.mz.id
    cidr_block = "10.0.21.0/24"
    availability_zone = "us-east-2b"
    tags = {
      Name = "mz-databasesubnet2"
    }
}
# Creating Internet Gateway (IGW)
resource "aws_internet_gateway" "igwmz" {
  vpc_id = aws_vpc.mz.id

  tags = {
    Name = "mzigw"
  }
}
# Creating Route Table for subnet1
resource "aws_route_table" "mzrtsubnet1" {
  vpc_id = aws_vpc.mz.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwmz.id
  }
  

  tags = {
    Name = "Route table from Subnet1"
  }
}

#Creating security groups
resource "aws_security_group" "allow_httpd" {
  name        = "allow_httpd"
  description = "Allow httpd inbound traffic"
  vpc_id      = aws_vpc.mz.id

  ingress {
    description      = "httpd from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_httpd"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"
  vpc_id      = aws_vpc.mz.id

  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

# Generate a secure key using a rsa algorithm
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# creating the keypair in aws
resource "aws_key_pair" "ec2_key" {
  key_name   = "terraform-key1"                 
  public_key = tls_private_key.ec2_key.public_key_openssh 
}

# Save the .pem file locally for remote connection
resource "local_file" "ssh_key" {
  filename = "terraform.pem"
  content  = tls_private_key.ec2_key.private_key_pem
}

# Creating instance in public subnet1
resource "aws_instance" "my-instance" {
  ami                     = "ami-01107263728f3bef4"
  instance_type           = "t2.micro"
  availability_zone = "us-east-2a"
  subnet_id = aws_subnet.mz-databasesubnet1.id
  associate_public_ip_address = "true"
  # user_data_base64
  key_name = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_httpd.id, aws_security_group.allow_ssh.id]
  }

# Creating Elastic IPs
resource "aws_eip" "fixed-ip" {
  instance = aws_instance.my-instance.id
  domain   = "vpc"
}

# Creating NAT gateway in Subnet1 to allow instance in private subnet to on the internet(0.0.0.0/0)
resource "aws_nat_gateway" "mzNAT" {
  allocation_id = aws_eip.fixed-ip.id
  subnet_id     = aws_subnet.mz-subnet1.id

  tags = {
    Name = "mz NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igwmz]
  }