# --- 1. Get latest Ubuntu 22.04 AMI ---
data "aws_ami" "ubuntu" {
  provider    = aws.mumbai
  most_recent = true
  owners      = ["099720109477"] # Canonical (Official Ubuntu Owner ID)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- 2. Generate SSH Key Pair (Terraform does the math) ---
resource "tls_private_key" "bastion_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- 3. Upload Public Key to AWS ---
resource "aws_key_pair" "bastion_auth" {
  provider   = aws.mumbai
  key_name   = "testkey"
  public_key = tls_private_key.bastion_key.public_key_openssh
}

# --- 4. Save Private Key to local file ---
resource "local_file" "private_key" {
  content         = tls_private_key.bastion_key.private_key_pem
  filename        = "${path.module}/testkey.pem"
  file_permission = "0400" # Read-only for owner (Required for SSH)
}

# --- 5. Security Group ---
resource "aws_security_group" "bastion_sg" {
  provider    = aws.mumbai
  name        = "Fvrk-dev-bastion-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: In production, replace this with your specific IP
  }

  # Added PostgreSQL rule
  ingress {
    description = "PostgreSQL from anywhere"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # WARNING: This rule is redundant if 22 and 5432 are already defined.
  # It essentially allows all traffic (ports 0-65535, all protocols) from anywhere.
  # I'll leave it since it was in your input, but best practice is to remove it.
  ingress {
    description = "All traffic from anywhere (DANGEROUS)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Fvrk-dev-bastion-sg"
  }
}

# --- 6. The Bastion Host Instance (UPDATED TO t2.medium) ---
resource "aws_instance" "bastion" {
  provider      = aws.mumbai
  ami           = "ami-0ade68f094cc81635"
  instance_type = "t2.medium" # Updated from t2.micro

  # Place in the first Public Subnet
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = aws_key_pair.bastion_auth.key_name
  # Removed 'associate_public_ip_address = true' because we will use the Elastic IP
  
  tags = {
    Name = "Fvrk-dev-bastion-host"
  }
}

# --- 7. Create Elastic IP (EIP) ---
resource "aws_eip" "bastion_ip" {
  provider = aws.mumbai
  domain   = "vpc" # Important: EIPs for instances in a VPC must have this set to true

  tags = {
    Name = "bastionhost-ip"
  }
}

# --- 8. Attach Elastic IP to the Bastion Instance ---
resource "aws_eip_association" "eip_assoc" {
  provider      = aws.mumbai
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion_ip.id
}

# --- 9. Manage Instance State (Stop the Bastion) ---
resource "aws_ec2_instance_state" "bastion_state" {
  provider    = aws.mumbai
  instance_id = aws_instance.bastion.id
  state       = "running" # Options: "running", "stopped"
}