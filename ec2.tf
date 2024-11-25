resource "aws_instance" "bastion" {
  ami           = data.aws_ssm_parameter.amzn2_ami.value
  instance_type = "t4g.nano"
  key_name      = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true
  disable_api_stop            = true
  disable_api_termination     = true
  user_data = templatefile(
    "${path.cwd}/files/startup_scripts/bastion.sh",
    {
      bastion_bucket = aws_s3_bucket.bastion.id
      iam_ssh_bucket = aws_s3_bucket.iam_ssh.id
    }
  )

  credit_specification {
    cpu_credits = "standard"
  }
  monitoring = true

  iam_instance_profile = aws_iam_instance_profile.bastion_instance.name

  root_block_device {
    volume_size = "8"
  }

  lifecycle {
    ignore_changes = [
      ami,
    ]
  }

  tags = {
    Name = "${local.project}-${local.env}-bastion"
  }
}

resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id

  tags = {
    Name = "${local.project}-${local.env}-bastion"
  }
}

resource "aws_key_pair" "bastion" {
  key_name   = "${local.project}-${local.env}-bastion"
  public_key = var.key_pair_pub
}

data "aws_ssm_parameter" "amzn2_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2"
}
