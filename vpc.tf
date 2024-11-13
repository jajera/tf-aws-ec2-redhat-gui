module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  database_subnets = local.database_subnets
  private_subnets  = local.private_subnets
  public_subnets   = local.public_subnets

  enable_dns_hostnames = local.enable_dns_hostnames
  enable_dns_support   = local.enable_dns_support
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = local.tags
}

data "http" "my_public_ip" {
  url = "http://ifconfig.me/ip"
}

module "security_group_instance_connect" {
  source  = "tfstack/security-group/aws"
  version = "1.0.7"

  name        = "${local.name}-instance-connect"
  description = "Instance connect security group"
  vpc_id      = module.vpc.vpc_id

  custom_ingress_rules = [
    {
      rule_name   = "ssh-22-tcp"
      cidr_ipv4   = "${data.http.my_public_ip.response_body}/32"
      description = "Allow SSH from specific public IP for administrative access"
      tags = {
        Purpose  = "Admin Access"
        Protocol = "TCP"
        Port     = "22"
        Access   = "Inbound"
      }
    }
  ]

  advance_egress_rules = [
    {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound traffic"
      tags = {
        Purpose  = "Any to any"
        Protocol = "-1"
        Port     = "0"
        Access   = "Outbound"
      }
    }
  ]

  tags = {
    Name = "instance-connect-${random_string.suffix.result}"
  }
}

module "security_group_rhel9" {
  source  = "tfstack/security-group/aws"
  version = "1.0.7"

  name        = "${local.name}-rhel9"
  description = "Security group for Rhel9"
  vpc_id      = module.vpc.vpc_id

  custom_ingress_rules = [
    {
      rule_name   = "ssh-22-tcp"
      cidr_ipv4   = "${data.http.my_public_ip.response_body}/32"
      description = "Allow SSH from specific public IP for administrative access"
      tags = {
        Purpose  = "Admin Access"
        Protocol = "TCP"
        Port     = "22"
        Access   = "Inbound"
      }
    },
    {
      rule_name   = "http-80-tcp"
      cidr_ipv4   = "${data.http.my_public_ip.response_body}/32"
      description = "Allow HTTP traffic on port 80 for web access"
      tags = {
        Purpose  = "Web Access"
        Protocol = "TCP"
        Port     = "80"
        Access   = "Inbound"
      }
    }
  ]

  advance_egress_rules = [
    {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all outbound traffic"
      tags = {
        Purpose  = "Any to any"
        Protocol = "-1"
        Port     = "0"
        Access   = "Outbound"
      }
    }
  ]

  tags = {
    Name = "rhel9-${random_string.suffix.result}"
  }
}

resource "aws_ec2_instance_connect_endpoint" "example" {
  subnet_id          = module.vpc.public_subnets[0]
  security_group_ids = [module.security_group_instance_connect.security_group_id]
  tags               = local.tags
}
