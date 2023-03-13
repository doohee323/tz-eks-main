##################################################################
# EKS k8sAdmin / k8sDev Role
##################################################################
resource "aws_iam_group" "k8sAdmin" {
  name = "${local.cluster_name}-k8sAdmin"
  path = "/users/"
}
resource "aws_iam_group_policy" "k8sAdmin_policy" {
  name  = "${local.cluster_name}-k8sAdmin"
  group = aws_iam_group.k8sAdmin.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-k8sAdmin"
      },
    ]
  })
}
resource "aws_iam_policy" "k8sAdmin" {
  name        = "${local.cluster_name}-k8sAdmin"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-k8sAdmin"
    }]
  })
}
resource "aws_iam_role" "k8sAdmin" {
  name     = "${local.cluster_name}-k8sAdmin"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = "sts:AssumeRole",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
    }]
  })
}

resource "aws_iam_user" "k8sAdmin" {
  name = "${local.cluster_name}-k8sAdmin"
}

##################################################################
resource "aws_iam_group" "k8sDev" {
  name = "${local.cluster_name}-k8sDev"
  path = "/users/"
}
resource "aws_iam_group_policy" "k8sDev_policy" {
  name  = "${local.cluster_name}-k8sDev"
  group = aws_iam_group.k8sDev.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-k8sDev"
      },
    ]
  })
}
resource "aws_iam_policy" "k8sDev" {
  name        = "${local.cluster_name}-k8sDev"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "sts:AssumeRole",
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.cluster_name}-k8sDev"
    }]
  })
}
resource "aws_iam_role" "k8sDev" {
  name     = "${local.cluster_name}-k8sDev"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Action    = "sts:AssumeRole",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
    }]
  })
}
resource "aws_iam_user" "k8sDev" {
  name = "${local.cluster_name}-k8sDev"
}
//resource "aws_iam_user_policy_attachment" "doohee-hong" {
//  user       = "doohee323"
//  policy_arn = aws_iam_policy.k8sAdmin.arn
//}
//resource "aws_iam_user_policy_attachment" "doogee-hong" {
//  user       = "doogee323"
//  policy_arn = aws_iam_policy.k8sDev.arn
//}
resource "aws_iam_group_membership" "k8sAdmin" {
  name = "${local.cluster_name}-k8sAdmin"
  users = [
    "${local.cluster_name}-k8sAdmin",
//    "doohee323"
  ]
  group = aws_iam_group.k8sAdmin.name
}
resource "aws_iam_group_membership" "k8sDev" {
  name = "${local.cluster_name}-k8sDev"
  users = [
    "${local.cluster_name}-k8sDev",
    "doogee323"
  ]
  group = aws_iam_group.k8sDev.name
}

#########################################
# IAM ECR policy
#########################################
module "iam_ecr_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  name        = "${local.cluster_name}-ecr-policy"
  path        = "/"
  description = "${local.cluster_name}-ecr-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "eks-main-ecr-policy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ecr-policy"
  role       = module.eks.cluster_iam_role_name
  depends_on = [module.iam_ecr_policy]
}
