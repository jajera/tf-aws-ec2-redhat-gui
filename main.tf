resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

locals {
  name = "ec2-redhat-pgadmin-${random_string.suffix.result}"

  tags = {
    UseCase = local.name
  }

  # vpc
  region               = "ap-southeast-1"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  database_subnets     = ["10.0.201.0/24", "10.0.202.0/24", "10.0.203.0/24"]
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "null_resource" "example" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "PGADMIN_SETUP_EMAIL=pgadmin@example.com" > terraform.tmp
      echo "PGADMIN_SETUP_PASSWORD=${random_password.pgadmin.result}" >> terraform.tmp
      echo "PGADMIN_URL=http://${aws_instance.rhel9.public_ip}/pgadmin4" >> terraform.tmp
      chmod +x terraform.tmp
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      rm -f terraform.tmp
    EOT
  }
}
