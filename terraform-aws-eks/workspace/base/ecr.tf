variable "image_tag_mutability" {
  type        = string
  default     = "MUTABLE"
}

# create an ECR repo at the app/image level
//resource "aws_ecr_repository" "devops-jenkins" {
//  name                 = "devops-jenkins"
//  image_tag_mutability = var.image_tag_mutability
//}
//
//resource "aws_ecr_repository" "devops-jenkins-slave" {
//  name                 = "devops-jenkins-slave"
//  image_tag_mutability = var.image_tag_mutability
//}

//resource "aws_ecr_repository" "devops-crawler" {
//  name                 = "devops-crawler"
//  image_tag_mutability = var.image_tag_mutability
//}

