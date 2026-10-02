TERRAFORM_DIR := infrastructure/terraform

.PHONY: terraform-fmt terraform-validate runtime-validate verify

terraform-fmt:
	terraform -chdir=$(TERRAFORM_DIR) fmt -check -recursive

terraform-validate:
	terraform -chdir=$(TERRAFORM_DIR) init -backend=false
	terraform -chdir=$(TERRAFORM_DIR) validate

runtime-validate:
	bash -n scripts/bootstrap-v0.sh scripts/render-librechat-env.sh
	node --check docker/librechat/mongodb-init.js
	cd docker/librechat && docker compose --env-file .env.example -f compose.yaml config --quiet

verify: terraform-fmt terraform-validate runtime-validate
