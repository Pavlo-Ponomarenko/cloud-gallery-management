
resource "aws_ecr_repository" "ecr_repo" {
  name = "cloud-gallery"
  image_tag_mutability = "MUTABLE"  # Allows image tags to be overwritten
}

resource "aws_ecr_lifecycle_policy" "ecr_repo_lifecycle_policy" {
  repository = aws_ecr_repository.ecr_repo.name
  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Delete untagged images older than 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}