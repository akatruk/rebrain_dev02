provider "aws" {
    access_key = var.access_key
    secret_key = var.secret_key
    region     = var.region
}

data "template_file" "myuserdata" {
  template = "${file("${path.cwd}/bootstrap.sh")}"
}

resource "aws_instance" "red_hat" {
    ami = var.ami_id
    user_data = "${data.template_file.myuserdata.template}"
    instance_type = "t3.small"
    tags = {
        Name = "Andrey Katruk"
        email = "a_katruk_live_com"
        module = "dev02"
    }
    key_name                = aws_key_pair.my_key.id
    vpc_security_group_ids  = [aws_security_group.allow_ssh.id]
}

resource "aws_key_pair" "my_key" {
  key_name   = "deployer-key"
  public_key = "${file("/Users/akatruk/.ssh/id_rsa.pub")}"
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow ssh inbound traffic"

  dynamic "ingress" {
    for_each = ["80", "81", "82", "22"]
    content {
    description = "ssh from VPC"
    from_port   = ingress.value
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
    Owner = "Andrey Katruk"
  }
}

data "aws_route53_zone" "main" {
  name         = "katruk.ru"
}

resource "aws_route53_record" "devops-a" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.web_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.red_hat.public_ip]
}

output "instance_ips" {
  value = aws_instance.red_hat.public_ip
}
