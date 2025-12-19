terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # --- ADDED: Force Helm Provider to Version 2.x ---
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
  }
}

# Provider for Mumbai Region (ap-south-1)
provider "aws" {
  region  = "ap-south-1"
  alias   = "mumbai"
  profile = "Fvrk-dev"
}

# Default Provider (For iam.tf and future files)
provider "aws" {
  region  = "ap-south-1"
  profile = "Fvrk-dev"
}