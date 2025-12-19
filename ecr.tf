# Define the list of repository names
locals {
  repositories = [
    "text-extraction",
    "document-classification",
    "page-classification",
    "field-extraction",
    "validus",
    "frame",
    "gateway",
    "frontend"
  ]
}

# Create each repository using a loop
resource "aws_ecr_repository" "app_repos" {
  for_each = toset(local.repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE" # Allows you to overwrite 'latest' tag (Standard for Dev)

  # Vulnerability scanning on push (Best Practice)
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = each.value
    Environment = "Fvrk-dev"
  }
}

# --- Optional: Lifecycle Policy (Clean up old images) ---
# This keeps only the last 10 images to save storage costs.
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  for_each   = toset(local.repositories)
  repository = aws_ecr_repository.app_repos[each.value].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}