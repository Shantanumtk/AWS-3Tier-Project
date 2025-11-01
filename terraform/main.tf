terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

############################################################
# 1. VPC, SUBNETS, ROUTES
############################################################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# public (ALB + bastion)
resource "aws_subnet" "public" {
  for_each = {
    a = { cidr = var.public_subnets[0], az = var.azs[0] }
    b = { cidr = var.public_subnets[1], az = var.azs[1] }
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${each.key}"
  }
}

# private app
resource "aws_subnet" "private_app" {
  for_each = {
    a = { cidr = var.private_app_subnets[0], az = var.azs[0] }
    b = { cidr = var.private_app_subnets[1], az = var.azs[1] }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${var.project_name}-private-app-${each.key}"
  }
}

# private db
resource "aws_subnet" "private_db" {
  for_each = {
    a = { cidr = var.private_db_subnets[0], az = var.azs[0] }
    b = { cidr = var.private_db_subnets[1], az = var.azs[1] }
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = "${var.project_name}-private-db-${each.key}"
  }
}

# public RT
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# NAT
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id

  tags = {
    Name = "${var.project_name}-nat"
  }
}

# private app RT -> NAT
resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-private-app-rt"
  }
}

resource "aws_route_table_association" "private_app" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app.id
}

# private db RT (no internet)
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db" {
  for_each       = aws_subnet.private_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}

############################################################
# 2. SECURITY GROUPS
############################################################

# bastion
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion SSH"
  vpc_id      = aws_vpc.this.id

  # tighten for prod
  ingress {
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

# public frontend ALB
resource "aws_security_group" "frontend_alb" {
  name        = "${var.project_name}-frontend-alb-sg"
  description = "Public FE ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
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

# frontend ec2
resource "aws_security_group" "frontend_ec2" {
  name        = "${var.project_name}-frontend-ec2-sg"
  description = "Frontend EC2"
  vpc_id      = aws_vpc.this.id

  # ALB -> 3000
  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_alb.id]
  }

  # bastion -> 22
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# internal backend ALB
resource "aws_security_group" "backend_alb" {
  name        = "${var.project_name}-backend-alb-sg"
  description = "Internal BE ALB"
  vpc_id      = aws_vpc.this.id

  # only FE EC2 can call
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# backend ec2
resource "aws_security_group" "backend_ec2" {
  name        = "${var.project_name}-backend-ec2-sg"
  description = "Backend EC2"
  vpc_id      = aws_vpc.this.id

  # only backend ALB -> 8000
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_alb.id]
  }

  # bastion -> 22
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# rds
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS PG"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################################
# 3. ALBs
############################################################

# public FE ALB
resource "aws_lb" "frontend" {
  name               = "${var.project_name}-frontend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_alb.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = {
    Name = "${var.project_name}-frontend-alb"
  }
}

resource "aws_lb_target_group" "frontend" {
  name     = "${var.project_name}-fe-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Name = "${var.project_name}-fe-tg"
  }
}

resource "aws_lb_listener" "frontend_http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

# internal BE ALB
resource "aws_lb" "backend" {
  name               = "${var.project_name}-backend-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_alb.id]
  subnets            = [for s in aws_subnet.private_app : s.id]

  tags = {
    Name = "${var.project_name}-backend-alb"
  }
}

resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-be-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }

  tags = {
    Name = "${var.project_name}-be-tg"
  }
}

resource "aws_lb_listener" "backend_http" {
  load_balancer_arn = aws_lb.backend.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

############################################################
# 4. IAM
############################################################

# backend EC2 -> secretsmanager
data "aws_iam_policy_document" "backend_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backend" {
  name               = "${var.project_name}-backend-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.backend_assume.json
}

resource "aws_iam_role_policy" "backend_sm" {
  name = "${var.project_name}-backend-sm"
  role = aws_iam_role.backend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret", "kms:Decrypt"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project_name}-backend-ec2-profile"
  role = aws_iam_role.backend.name
}

# frontend EC2 -> describe LBs
data "aws_iam_policy_document" "frontend_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "frontend" {
  name               = "${var.project_name}-frontend-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.frontend_assume.json
}

resource "aws_iam_role_policy" "frontend_elb" {
  name = "${var.project_name}-frontend-elb"
  role = aws_iam_role.frontend.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["elasticloadbalancing:DescribeLoadBalancers"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "frontend" {
  name = "${var.project_name}-frontend-ec2-profile"
  role = aws_iam_role.frontend.name
}

############################################################
# 5. UBUNTU AMI
############################################################

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

############################################################
# 6. RDS + SECRETS
############################################################

resource "random_password" "db" {
  length  = 16
  special = false
}

locals {
  db_password = var.db_password_override != "" ? var.db_password_override : random_password.db.result
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private_db : s.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_db_instance" "this" {
  identifier             = "${var.project_name}-postgres"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = var.db_name
  username               = "postgres"
  password               = local.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "${var.project_name}-rds"
  }
}

resource "random_id" "secret_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.project_name}-db-secret-${random_id.secret_suffix.hex}"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id  = aws_secretsmanager_secret.db.id
  depends_on = [aws_db_instance.this]

  secret_string = jsonencode({
    username = "postgres"
    password = local.db_password
    host     = aws_db_instance.this.address
    port     = 5432
    dbname   = var.db_name
  })
}

############################################################
# 7. EC2 INSTANCES
############################################################

# 7.0 Bastion
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public["a"].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    apt-get update -y
    apt-get install -y htop git
  EOF

  tags = {
    Name = "${var.project_name}-bastion"
  }
}

# 7.1 Frontend A
resource "aws_instance" "frontend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.frontend_instance_type
  subnet_id              = aws_subnet.private_app["a"].id
  vpc_security_group_ids = [aws_security_group.frontend_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.frontend.name
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
#!/bin/bash
set -eux

mkdir -p /opt
cd /opt

# placeholder so ALB is happy
cat >/opt/health.html <<'HTML'
<html><body><h1>frontend booting...</h1></body></html>
HTML

nohup python3 -m http.server 3000 --directory /opt >/var/log/frontend-placeholder.log 2>&1 &

# real script (no hardcoded ALB inside)
cat >/opt/bootstrap-frontend.sh <<'SCRIPT'
#!/usr/bin/env bash
set -eux

wait_for_net() {
  for i in $(seq 1 15); do
    if curl -s --connect-timeout 3 http://aws.amazon.com >/dev/null; then
      return 0
    fi
    echo "net not ready, sleeping ($i/15)"
    sleep 5
  done
  return 0
}

retry_apt_update() {
  for i in $(seq 1 10); do
    if apt-get update -y; then return 0; fi
    echo "apt-get update failed ($i/10)"
    sleep 5
  done
  return 1
}

retry_apt_install() {
  PKGS="$@"
  for i in $(seq 1 10); do
    if DEBIAN_FRONTEND=noninteractive apt-get install -y $PKGS; then return 0; fi
    echo "apt-get install failed ($i/10) for $PKGS"
    sleep 5
  done
  return 1
}

# must be injected by Terraform
if [ -z "$${BACKEND_URL:-}" ]; then
  echo "BACKEND_URL not set, exiting"
  exit 1
fi

wait_for_net
retry_apt_update
retry_apt_install git curl python3-pip

# Node.js
for i in $(seq 1 5); do
  if curl -fsSL https://deb.nodesource.com/setup_20.x | bash -; then
    break
  fi
  echo "nodesource failed ($i/5)"
  sleep 5
done
retry_apt_install nodejs build-essential

cd /opt
if [ ! -d "/opt/app" ]; then
  for i in $(seq 1 5); do
    if git clone https://github.com/Shantanumtk/AWS-3Tier-Project.git app; then
      break
    fi
    echo "git clone failed ($i/5)"
    sleep 5
  done
else
  cd /opt/app
  git pull || true
  cd /opt
fi

cd /opt/app/frontend

# install deps
for i in $(seq 1 5); do
  if npm install; then
    break
  fi
  echo "npm install failed ($i/5)"
  sleep 5
done

# build react (non-interactive)
CI=true npm run build

# runtime config (browser) – always /api
echo "window.__APP_CONFIG__ = { API_BASE: '/api' };" >/opt/app/frontend/build/config.js

# stop placeholder
pkill -f "python3 -m http.server 3000" || true

# start express+proxy with injected backend
nohup env BACKEND_URL="$BACKEND_URL" node /opt/app/frontend/server.js >/var/log/frontend.log 2>&1 &
SCRIPT

chmod +x /opt/bootstrap-frontend.sh

# now call it with real backend alb from terraform
BACKEND_URL="http://${aws_lb.backend.dns_name}:8000" /opt/bootstrap-frontend.sh >/var/log/bootstrap-frontend.log 2>&1 &
  EOF

  tags = {
    Name = "${var.project_name}-frontend-a"
  }
}

# 7.2 Frontend B (same userdata)
resource "aws_instance" "frontend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.frontend_instance_type
  subnet_id              = aws_subnet.private_app["b"].id
  vpc_security_group_ids = [aws_security_group.frontend_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.frontend.name
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = aws_instance.frontend_a.user_data

  tags = {
    Name = "${var.project_name}-frontend-b"
  }
}

# 7.3 Backend A
resource "aws_instance" "backend_a" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.private_app["a"].id
  vpc_security_group_ids = [aws_security_group.backend_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.backend.name
  key_name               = var.key_name != "" ? var.key_name : null

  depends_on = [
    aws_db_instance.this,
    aws_secretsmanager_secret_version.db
  ]

  user_data = <<-EOF
#!/bin/bash
set -eux

wait_for_net() {
  for i in $(seq 1 15); do
    if curl -s --connect-timeout 3 http://aws.amazon.com >/dev/null; then
      return 0
    fi
    echo "net not ready, sleeping ($i/15)"
    sleep 5
  done
  return 0
}

retry_apt_update() {
  for i in $(seq 1 10); do
    if apt-get update -y; then return 0; fi
    echo "apt-get update failed ($i/10)"
    sleep 5
  done
  return 1
}

retry_apt_install() {
  PKGS="$@"
  for i in $(seq 1 10); do
    if DEBIAN_FRONTEND=noninteractive apt-get install -y $PKGS; then return 0; fi
    echo "apt-get install failed ($i/10) for $PKGS"
    sleep 5
  done
  return 1
}

wait_for_db() {
  HOST="${aws_db_instance.this.address}"
  for i in $(seq 1 30); do
    if nc -z "$HOST" 5432; then
      return 0
    fi
    echo "db not ready, sleeping ($i/30)"
    sleep 5
  done
  return 0
}

wait_for_net
retry_apt_update
retry_apt_install git python3 python3-venv python3-pip awscli netcat

mkdir -p /opt
cd /opt

if [ ! -d "/opt/app" ]; then
  for i in $(seq 1 5); do
    if git clone https://github.com/Shantanumtk/AWS-3Tier-Project.git app; then
      break
    fi
    echo "git clone failed ($i/5)"
    sleep 5
  done
else
  cd /opt/app
  git pull || true
  cd /opt
fi

cd /opt/app/backend

python3 -m venv /opt/app/backend/venv
. /opt/app/backend/venv/bin/activate
pip install --upgrade pip

if [ -f requirements.txt ]; then
  for i in $(seq 1 5); do
    if pip install -r requirements.txt; then
      break
    fi
    echo "pip install -r requirements.txt failed ($i/5)"
    sleep 5
  done
fi

wait_for_db

cat >/etc/systemd/system/backend.service <<SYS
[Unit]
Description=FastAPI Backend
After=network.target
Wants=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/app/backend
Environment=AWS_REGION=${var.aws_region}
Environment=AWS_SECRET_NAME=${aws_secretsmanager_secret.db.name}
ExecStart=/opt/app/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYS

systemctl daemon-reload
systemctl enable --now backend.service
  EOF

  tags = {
    Name = "${var.project_name}-backend-a"
  }
}

# 7.4 Backend B
resource "aws_instance" "backend_b" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.backend_instance_type
  subnet_id              = aws_subnet.private_app["b"].id
  vpc_security_group_ids = [aws_security_group.backend_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.backend.name
  key_name               = var.key_name != "" ? var.key_name : null

  depends_on = [
    aws_db_instance.this,
    aws_secretsmanager_secret_version.db
  ]

  user_data = aws_instance.backend_a.user_data

  tags = {
    Name = "${var.project_name}-backend-b"
  }
}

############################################################
# 8. ALB ATTACHMENTS
############################################################

resource "aws_lb_target_group_attachment" "frontend_a" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend_a.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "frontend_b" {
  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = aws_instance.frontend_b.id
  port             = 3000
}

resource "aws_lb_target_group_attachment" "backend_a" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_a.id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "backend_b" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend_b.id
  port             = 8000
}
