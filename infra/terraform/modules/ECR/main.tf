 # Create one ECR repository per configured image target.
resource "aws_ecr_repository" "this" {
  for_each = { for r in var.repositories : r["name"] => r }

  name                 = each.value["name"]
  image_tag_mutability = lookup(each.value, "image_tag_mutability", var.image_tag_mutability)

  image_scanning_configuration {
    scan_on_push = lookup(each.value, "scan_on_push", var.scan_on_push)
  }

  encryption_configuration {
    encryption_type = lookup(each.value, "encryption_type", var.encryption_type)
    kms_key         = lookup(each.value, "kms_key", var.kms_key)
  }

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

 # Attach lifecycle rules only where the repository definition supplies them.
resource "aws_ecr_lifecycle_policy" "this" {
  for_each = { for r in var.repositories : r["name"] => r if contains(keys(r), "lifecycle_policy") && r["lifecycle_policy"] != "" }

  repository = each.key
  policy     = each.value["lifecycle_policy"]
}

 # Apply any repository-level access policy passed in with the repository definition.
resource "aws_ecr_repository_policy" "this" {
  for_each = { for r in var.repositories : r["name"] => r if contains(keys(r), "policy") && r["policy"] != "" }

  repository = each.key
  policy     = each.value["policy"]
}
