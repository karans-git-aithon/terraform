# --- 1. Create the New EFS File System ---
resource "aws_efs_file_system" "text_extraction_efs" {
  creation_token = "text-extraction-data"
  encrypted      = true

  tags = {
    Name = "Text-Extraction-Data" # Easy to spot in Console
  }
}

# --- 2. Create Security Group for EFS ---
# Allows traffic from your EKS Nodes and Admin EC2
resource "aws_security_group" "efs_sg" {
  name        = "text-extraction-efs-sg"
  description = "Allow NFS traffic for Text Extraction EFS"
  vpc_id      = aws_vpc.main.id # Ensure this matches your VPC variable

  # Allow NFS (2049) from within the VPC (Simple & Secure for internal use)
  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 3. Create Mount Targets (One per AZ) ---
resource "aws_efs_mount_target" "efs_mt" {
  # LOGIC CHANGE:
  # Instead of looping through ALL subnets (count = length...), 
  # we loop through a map of UNIQUE Availability Zones.
  for_each = { 
    for subnet in aws_subnet.public : subnet.availability_zone => subnet.id... 
  }

  file_system_id  = aws_efs_file_system.text_extraction_efs.id
  
  # We select the first subnet found for each unique AZ
  subnet_id       = each.value[0]
  
  security_groups = [aws_security_group.efs_sg.id]
}

# ============================================================================
# NEW EFS: Aithon Data (for general purpose data storage)
# ============================================================================

# --- 4. Create the NEW EFS File System (aithon-data) ---
resource "aws_efs_file_system" "aithon_efs" {
  creation_token = "aithon-general-data"
  encrypted      = true

  tags = {
    Name = "Aithon-General-Data" # New name for identification
  }
}

# --- 5. Create Security Group for Aithon EFS ---
# Required even if permissions are the same, to link to the new Mount Targets
resource "aws_security_group" "aithon_efs_sg" {
  name        = "aithon-data-efs-sg"
  description = "Allow NFS traffic for Aithon Data EFS"
  vpc_id      = aws_vpc.main.id # Ensure this matches your VPC variable

  # Allow NFS (2049) from within the VPC
  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 6. Create Mount Targets for Aithon EFS (One per AZ) ---
# NOTE: This block uses the same logic as the previous one but links to the NEW File System ID
resource "aws_efs_mount_target" "aithon_efs_mt" {
  # Loop through unique Availability Zones
  for_each = { 
    for subnet in aws_subnet.public : subnet.availability_zone => subnet.id... 
  }

  file_system_id  = aws_efs_file_system.aithon_efs.id # <-- Links to the NEW EFS
  
  # Select the first subnet found for each unique AZ
  subnet_id       = each.value[0]
  
  security_groups = [aws_security_group.aithon_efs_sg.id]
  
  # Ensure the VPC and subnets are created before the mount targets
  depends_on = [
    aws_efs_file_system.aithon_efs,
  ]
}

# --- 7. Output the New EFS ID ---
output "aithon_efs_id" {
  value = aws_efs_file_system.aithon_efs.id
  description = "The File System ID for the Aithon General Data EFS"
}