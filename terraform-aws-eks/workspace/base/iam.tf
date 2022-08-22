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
//resource "aws_iam_user" "k8sAdmin" {
//  name = "${local.cluster_name}-k8sAdmin"
//}

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
//resource "aws_iam_user" "k8sDev" {
//  name = "${local.cluster_name}-k8sDev"
//}
//resource "aws_iam_user_policy_attachment" "doohee-hong" {
//  user       = "doohee.hong"
//  policy_arn = aws_iam_policy.k8sAdmin.arn
//}
//resource "aws_iam_user_policy_attachment" "doogee-hong" {
//  user       = "doogee.hong"
//  policy_arn = aws_iam_policy.k8sDev.arn
//}
resource "aws_iam_group_membership" "k8sAdmin" {
  name = "${local.cluster_name}-k8sAdmin"
  users = [
    "doohee.hong"
  ]
  group = aws_iam_group.k8sAdmin.name
}
resource "aws_iam_group_membership" "k8sDev" {
  name = "${local.cluster_name}-k8sDev"
  users = [
    "doogee.hong"
  ]
  group = aws_iam_group.k8sDev.name
}

##################################################################
# bastion-eks-main
##################################################################
//resource "aws_iam_role" "bastion-eks-main-role" {
//  name               = "bastion-${local.cluster_name}-role"
//  assume_role_policy = <<EOF
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Action": "sts:AssumeRole",
//      "Principal": {
//        "Service": "ec2.amazonaws.com"
//      },
//      "Effect": "Allow",
//      "Sid": ""
//    }
//  ]
//}
//EOF
//
//}
//
//resource "aws_iam_instance_profile" "bastion-eks-main-role" {
//  name = "bastion-${local.cluster_name}-role"
//  role = aws_iam_role.bastion-eks-main-role.name
//}
//
//resource "aws_iam_role_policy" "admin-policy" {
//  name = "bastion-${local.cluster_name}-policy"
//  role = aws_iam_role.bastion-eks-main-role.id
//
//  policy = <<-EOF
//  {
//    "Version": "2012-10-17",
//    "Statement": [
//      {
//        "Action": [
//          "*"
//        ],
//        "Effect": "Allow",
//        "Resource": "*"
//      }
//    ]
//  }
//  EOF
//}

//#########################################
//# IAM ECR policy
//#########################################
//module "iam_ecr_policy" {
//  source = "../../modules/iam-policy"
//  name        = "${local.cluster_name}-ecr-policy"
//  path        = "/"
//  description = "${local.cluster_name}-ecr-policy"
//  policy = <<EOF
//{
//  "Version": "2012-10-17",
//  "Statement": [
//    {
//      "Action": [
//        "ecr:*"
//      ],
//      "Effect": "Allow",
//      "Resource": "*"
//    }
//  ]
//}
//EOF
//}
resource "aws_iam_role_policy_attachment" "eks-main-ecr-policy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ecr-policy"
  role       = module.eks.cluster_iam_role_name
}
#########################################
# IAM S3 policy
#########################################
resource "aws_iam_role_policy_attachment" "eks-main3full-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = module.eks.cluster_iam_role_name
}
module "es_s3_iam_policy" {
  source = "../../modules/iam-policy"
  name        = "${local.cluster_name}-es-s3-policy"
  path        = "/"
  description = "${local.cluster_name}-es-s3-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:*"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::devops-es-${local.cluster_name}",
        "arn:aws:s3:::devops-es-${local.cluster_name}/*"
      ]
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "eks-main-es-s3-policy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-es-s3-policy"
  role       = var.map_roles[0].username
  depends_on = [module.es_s3_iam_policy]
}
#########################################
# IAM SES policy
#########################################
module "iam_ses_policy" {
  source = "../../modules/iam-policy"
  name        = "${local.cluster_name}-ses-policy"
  path        = "/"
  description = "${local.cluster_name}-ses-policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ses:SendRawEmail"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "eks-main-ses-policy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-ses-policy"
  role       = module.eks.cluster_iam_role_name
  depends_on = [module.iam_ses_policy]
}

#########################################
# ingress-nginx dns-01
#########################################
module "cert_manager_irsa" {
//  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
//  version = "3.6.0"
  source = "../../modules/iam-assumable-role-with-oidc"
  create_role = true
  role_name = "cert_manager-${local.cluster_name}"
  tags = {Role = "cert_manager-${local.cluster_name}-with-oidc"}
  provider_url  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [aws_iam_policy.cert_manager_policy.arn]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:${local.k8s_service_account_namespace}:${local.k8s_service_account_name}",
    "arn:aws:iam::xxxxxxxxxxxxxx:user/doohee.hong"
  ]
}

resource "aws_iam_policy" "cert_manager_policy" {
  name        = "${local.cluster_name}-cert-manager-policy"
  path        = "/"
  description = "Policy, which allows CertManager to create Route53 records"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : "route53:GetChange",
        "Resource" : "arn:aws:route53:::change/*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ],
        "Resource": "arn:aws:route53:::hostedzone/*"
      },
      {
        "Effect": "Allow",
        "Action": "route53:ListHostedZonesByName",
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks-main-cert_manager_policy" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.cluster_name}-cert-manager-policy"
  role       = var.map_roles[0].username
}

##################
