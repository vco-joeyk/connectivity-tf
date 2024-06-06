#AWS Provider
terraform {
  required_providers {
    aws = {
        source  = "Hashicorp/aws"
        version = "5.10.0"
    }
  }
}

provider "aws" {
    region  = "eu-west-1"
}

resource "aws_vpc" "wp_vpc" {
  cidr_block = "10.100.0.0/16"
  tags = {
    "Name" = "vco-vpc"
  }
}

resource "aws_subnet" "public1" {
    vpc_id            = aws_vpc.wp_vpc.id
    cidr_block        = "10.100.1.0/24"
    availability_zone = "eu-west-1a"

    tags = {
      Name = "vco-public-1"
    }
}

resource "aws_subnet" "public2" {
    vpc_id            = aws_vpc.wp_vpc.id
    cidr_block        = "10.100.1.0/24"
    availability_zone = "eu-west-1b"

    tags = {
      Name = "vco-public-2"
    }
}


resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.wp_vpc.id
  cidr_block        = "10.100.3.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "vco-private-1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.wp_vpc.id
  cidr_block        = "10.100.3.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "vco-private-2"
  }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.wp_vpc.id

    tags = {
        Name = "vco-igw"
    }
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "vco-nat"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.wp_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
    vpc_id = aws_vpc.wp_vpc.id

    route {
        cidr_block      = "0.0.0.0/0"
        nat_gateway_id  = aws_nat_gateway.nat.id
    }

    tags = {
        Name = "vco-private-rt"
    }
}

resource "aws_route_table_association" "public1" {
  subnet_id       = aws_subnet.public1.id
  route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id       = aws_subnet.public2.id
  route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id       = aws_subnet.private1.id
  route_table_id  = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id       = aws_subnet.private2.id
  route_table_id  = aws_route_table.private.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow (selected) inbound SSH traffic"
  vpc_id      = aws_vpc.wp_vpc.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port         = 0
    to_port           = 0
    protocol          = "-1"
    cidr_blocks       = ["0.0.0.0/0"]
    ipv6_cidr_blocks  = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "wordpress" {
    ami                         = data.aws_ami.amazon-linux-2
    instance_type               = "t2.micro"
    key_name                    = "vcowp_key.pem"
    subnet_id                   = aws_subnet.public1.id
    security_groups             = [aws_security_group.allow_ssh.id]
    associate_public_ip_address = true
}

resource "aws_db_subnet_group" "rds_subnet_group" {
    name        = "rds-subnet-group"
    subnet_ids  = [aws_subnet.private1.id, aws_subnet.private2.id]
}

resource "aws_db_instance" "rds_instance" {
    engine                    = "postgresql"
    engine_version            = "14"
    skip_final_snapshot       = true
    final_snapshot_identifier = "idunno"
    instance_class            = "db.t2.micro"
    allocated_storage         = 20
    identifier                = "wp-rds-instance"
    db_name                   = "wordpress_db"
    username                  = "postgres"
    password                  = "postgres"
    db_subnet_group_name      = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids    = [aws_security_group.rds_security_group.id]

    tags = {
        Name = "RDS Instance"
    }
}

resource "aws_security_group" "rds_security_group" {
    name        = "rds-security-group"
    description = "Security group for RDS instance"
    vpc_id      = aws_vpc.wp_vpc.id

    ingress {
        from_port   = 5432
        to_port     = 5432
        protocol    = "tcp"
        cidr_blocks = ["10.100.0.0/16"]
    }

    tags = {
        Name = "RDS Security Group"
    }
}

/*
    The 3 resources created unnder here
    are to do the following: 
    1. Create a private key
    2. Generate key pair
    3. Save the key pair to allocated key file
*/
resource "tls_private_key" "vcowp_idrsa" {
    algorithm = "RSA"
}

resource "aws_key_pair" "vcowp_deployer" {
  key_name    = "vcpwp_key"
  public_key  = tls_private_key.vcowp_idrsa.public_key_openssh
}

resource "null_resource" "vcowp_keysave" {
    provisioner "local-exec" {
        command = "echo ${tls_private_key.vcowp_idrsa.private_key_pem} > vcowp_key.pem"
    }
}