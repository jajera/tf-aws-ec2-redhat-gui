data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's official AWS owner ID

  filter {
    name   = "name"
    values = ["RHEL-9*_HVM-*-x86_64-*"] # Pattern to match RHEL 9 AMIs
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_password" "pgadmin" {
  length  = 16
  lower   = true
  numeric = true
  special = false
  upper   = true
}

resource "aws_instance" "rhel9" {
  ami                         = data.aws_ami.rhel9.id
  associate_public_ip_address = true
  instance_type               = "m5.xlarge"
  subnet_id                   = module.vpc.public_subnets[0]

  user_data = <<-EOF
              #!/bin/bash
              hostnamectl set-hostname rhel9

              # ec2 instance connect
              mkdir /tmp/ec2-instance-connect
              curl https://amazon-ec2-instance-connect-us-west-2.s3.us-west-2.amazonaws.com/latest/linux_amd64/ec2-instance-connect.rpm -o /tmp/ec2-instance-connect/ec2-instance-connect.rpm
              curl https://amazon-ec2-instance-connect-us-west-2.s3.us-west-2.amazonaws.com/latest/linux_amd64/ec2-instance-connect-selinux.noarch.rpm -o /tmp/ec2-instance-connect/ec2-instance-connect-selinux.rpm
              dnf install -y /tmp/ec2-instance-connect/ec2-instance-connect.rpm /tmp/ec2-instance-connect/ec2-instance-connect-selinux.rpm

              # pgadmin
              dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
              dnf install -y https://ftp.postgresql.org/pub/pgadmin/pgadmin4/yum/pgadmin4-redhat-repo-2-1.noarch.rpm
              dnf -q -y makecache --refresh
              dnf install -y pgadmin4
              systemctl start httpd
              systemctl enable httpd
              export PGADMIN_SETUP_EMAIL="pgadmin@example.com"
              export PGADMIN_SETUP_PASSWORD="${random_password.pgadmin.result}"
              /usr/pgadmin4/bin/setup-web.sh --yes
              EOF

  vpc_security_group_ids = [
    module.security_group_rhel9.security_group_id
  ]

  tags = {
    Name    = "${local.name}-rhel9"
    UseCase = local.name
  }
}
