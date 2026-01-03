terraform {
  backend "s3" {
    bucket = "3-tier-project-backend-43"
    key    = "terraform.tf"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.region
}

# ------------------ VPC ------------------

resource "aws_vpc" "three-tier-vpc" {
  region     = var.region
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ------------------ SUBNETS ------------------

resource "aws_subnet" "public-subnet" {
  vpc_id                  = aws_vpc.three-tier-vpc.id
  cidr_block              = var.cidr_pub_sub
  availability_zone       = var.az1
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-pub-subnet"
  }
}

resource "aws_subnet" "pri-subnet-1" {
  vpc_id            = aws_vpc.three-tier-vpc.id
  cidr_block        = var.cidr_pri_sub_1
  availability_zone = var.az2

  tags = {
    Name = "${var.project_name}-pri-subnet-1"
  }
}

resource "aws_subnet" "pri-subnet-2" {
  vpc_id            = aws_vpc.three-tier-vpc.id
  cidr_block        = var.cidr_pri_sub_2
  availability_zone = var.az3

  tags = {
    Name = "${var.project_name}-pri-subnet-2"
  }
}

# ------------------ INTERNET GATEWAY ------------------

resource "aws_internet_gateway" "three-tier-igw" {
  vpc_id = aws_vpc.three-tier-vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_default_route_table" "three-tier-rt" {
  default_route_table_id = aws_vpc.three-tier-vpc.default_route_table_id

  tags = {
    Name = "${var.project_name}-main-rt"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_default_route_table.three-tier-rt.id
  destination_cidr_block = var.igw_cidr
  gateway_id             = aws_internet_gateway.three-tier-igw.id
}

# ------------------ NAT ------------------

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "three-tier-nat-eip"
  }
}

resource "aws_nat_gateway" "three-tier-nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public-subnet.id

  depends_on = [aws_internet_gateway.three-tier-igw]
}

resource "aws_route_table" "three-tier-priv-rt" {
  vpc_id = aws_vpc.three-tier-vpc.id

  tags = {
    Name = "${var.project_name}-priv-rt"
  }
}

resource "aws_route" "nat-route" {
  route_table_id         = aws_route_table.three-tier-priv-rt.id
  destination_cidr_block = var.nat_cidr
  nat_gateway_id         = aws_nat_gateway.three-tier-nat.id
}

resource "aws_route_table_association" "association-1" {
  route_table_id = aws_route_table.three-tier-priv-rt.id
  subnet_id      = aws_subnet.pri-subnet-1.id
}

resource "aws_route_table_association" "association-2" {
  route_table_id = aws_route_table.three-tier-priv-rt.id
  subnet_id      = aws_subnet.pri-subnet-2.id
}

# ------------------ SECURITY GROUP ------------------

resource "aws_security_group" "three-tier-sg" {
  vpc_id      = aws_vpc.three-tier-vpc.id
  name        = "${var.project_name}-sg"
  description = "allow ssh, http and mysql traffic and for proxy allow 81"

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 81
    to_port     = 81
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_vpc.three-tier-vpc]
}

# ------------------ INSTANCES ------------------

resource "aws_instance" "public-server" {
  subnet_id              = aws_subnet.public-subnet.id
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key
  vpc_security_group_ids = [aws_security_group.three-tier-sg.id]

  tags = {
    Name = "${var.project_name}proxy-server"
  }

  depends_on = [aws_security_group.three-tier-sg]
}

resource "aws_instance" "private-server-1" {
  subnet_id              = aws_subnet.pri-subnet-1.id
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key
  vpc_security_group_ids = [aws_security_group.three-tier-sg.id]

  tags = {
    Name = "${var.project_name}app-server"
  }

  depends_on = [aws_security_group.three-tier-sg]
}

resource "aws_instance" "private-server-2" {
  subnet_id              = aws_subnet.pri-subnet-2.id
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key
  vpc_security_group_ids = [aws_security_group.three-tier-sg.id]

  tags = {
    Name = "${var.project_name}db-server"
  }

  depends_on = [aws_security_group.three-tier-sg]
}

# ---------- INVENTORY TEMPLATE RENDERING ----------

data "template_file" "ansible_inventory" {
  template = file("${path.module}/inventory.tmpl")

  vars = {
    proxy_public_ip = aws_instance.public-server.public_ip
    app_private_ip  = aws_instance.private-server-1.private_ip
    db_private_ip   = aws_instance.private-server-2.private_ip
  }
}

resource "local_file" "create_inventory" {
  content  = data.template_file.ansible_inventory.rendered
  filename = "${path.module}/../ansible/inventory.ini"
}

resource "null_resource" "run_ansible" {
  depends_on = [
    local_file.create_inventory
  ]

  provisioner "local-exec" {
    command = "cd ../ansible && ansible-playbook -i inventory.ini playbook.yml"
  }
}
