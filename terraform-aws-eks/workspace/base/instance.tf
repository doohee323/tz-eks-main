//data "aws_ami" "ubuntu" {
//  most_recent = true
//  filter {
//    name   = "name"
//    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
//  }
//  filter {
//    name   = "virtualization-type"
//    values = ["hvm"]
//  }
//  owners = ["099720109477"] # Canonical
//}
//
//resource "aws_instance" "eks-main-bastion" {
//  ami                  = data.aws_ami.ubuntu.id
////  ami                  = data.aws_ami.eks-main-bastion.id
//  instance_type          = "t3.small"
//  subnet_id              = module.vpc.public_subnets[0]
//  vpc_security_group_ids = [aws_security_group.eks-main-dev-bastion.id]
//  key_name = aws_key_pair.main.key_name
//  user_data = data.template_cloudinit_config.eks-main-bastion-cloudinit.rendered
//  iam_instance_profile = aws_iam_instance_profile.bastion-eks-main-role.name
////  disable_api_termination = true
//  tags          = {
//    team = "devops",
//    Name = "${local.cluster_name}-bastion"
//  }
//  ebs_block_device {
//    device_name = "/dev/sda1"
//    volume_type = "gp3"
//    volume_size = 50
//    delete_on_termination = false
//  }
//  provisioner "file" {
//    source      = "../../resource"
//    destination = "/home/ubuntu/resources"
//    connection {
//      type = "ssh"
//      user = "ubuntu"
//      host = self.public_ip
//      private_key = file("./${local.cluster_name}")
//    }
//  }
//}
//
////resource "aws_ebs_volume" "eks-main-bastion-data" {
////  availability_zone = "${local.region}a"
////  size              = 100
////  type              = "gp2"
////  tags = {
////    Name = "eks-main-bastion-data"
////  }
////}
////resource "aws_volume_attachment" "eks-main-bastion-data-attachment" {
////  device_name  = var.INSTANCE_DEVICE_NAME
////  volume_id    = aws_ebs_volume.eks-main-bastion-data.id
////  instance_id  = aws_instance.eks-main-bastion.id
////  skip_destroy = true
////  force_detach = true
////}
