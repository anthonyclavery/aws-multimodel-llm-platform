# EC2 AMI maintenance

The V0 instance AMI is intentionally pinned by the `ami_id` variable.
Using a "latest" AMI source would replace the instance at the next
`terraform apply`, including when an unrelated change is made.

To update the image, schedule a maintenance window, back up the EBS data,
update `ami_id`, review a plan that shows the EC2 instance replacement, then
explicitly apply that operation. Do not use this procedure for an ordinary
infrastructure change.
