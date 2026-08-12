data "aws_route53_zone" "external_dns_zones" {
  for_each = toset(var.external_dns_zones)
  name     = each.value
}

locals {
  zone_ids = concat(values(data.aws_route53_zone.external_dns_zones)[*].id, [var.subzone_id])
  zone_arns = [for id in local.zone_ids : "arn:aws:route53:::hostedzone/${id}"]
}

resource "aws_iam_role" "external-dns" {
  name               = "${var.environment}-external-dns"
  path               = "/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "AWS": [
            "arn:aws:iam::${local.accountid}:role/nodes.${var.cluster_name}",
            "arn:aws:iam::${local.accountid}:role/masters.${var.cluster_name}"
          ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "external-dns" {
  name        = "${var.environment}-external-dns"
  path        = "/"
  description = "External DNS for ${var.cluster_name}"
  policy      = jsonencode(
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetChange",
        "route53:ListHostedZonesByName",
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:DescribeLoadBalancers",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ChangeResourceRecordSets",
      "Resource": "${local.zone_arns}"
    }
  ]
})
}

resource "aws_iam_role_policy_attachment" "external-dns-attachment" {
  role       = aws_iam_role.external-dns.name
  policy_arn = aws_iam_policy.external-dns.arn
}

resource "aws_iam_role_policy_attachment" "external-dns-attachment2" {
  role       = aws_iam_role.external-dns.name
  policy_arn = aws_iam_policy.external-dns.arn
}
