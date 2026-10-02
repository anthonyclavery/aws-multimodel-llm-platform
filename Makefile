TERRAFORM_DIR := infrastructure/terraform
BOOTSTRAP_TERRAFORM_DIR := infrastructure/bootstrap

.PHONY: terraform-fmt terraform-validate terraform-plan bootstrap-terraform-fmt bootstrap-terraform-validate runtime-validate verify

terraform-fmt:
	terraform -chdir=$(TERRAFORM_DIR) fmt -check -recursive

terraform-validate:
	terraform -chdir=$(TERRAFORM_DIR) init -backend=false
	terraform -chdir=$(TERRAFORM_DIR) validate

terraform-plan:
	./scripts/terraform-plan.sh

bootstrap-terraform-fmt:
	terraform -chdir=$(BOOTSTRAP_TERRAFORM_DIR) fmt -check -recursive

bootstrap-terraform-validate:
	terraform -chdir=$(BOOTSTRAP_TERRAFORM_DIR) init -backend=false
	terraform -chdir=$(BOOTSTRAP_TERRAFORM_DIR) validate

runtime-validate:
	bash -n scripts/bootstrap-v0.sh scripts/render-librechat-env.sh
	node --check docker/librechat/mongodb-init.js
	cd docker/librechat && docker compose --env-file .env.example -f compose.yaml config --quiet

verify: terraform-fmt terraform-validate bootstrap-terraform-fmt bootstrap-terraform-validate runtime-validate
