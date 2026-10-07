# Deploying LibreChat from EC2

LibreChat changes are applied by the operator directly from the EC2 instance.
The agent prepares, evaluates, and verifies changes, but never runs the
deployment script on behalf of the operator.

From the repository clone on the EC2 instance, run:

```sh
./scripts/deploy-librechat-on-ec2.sh
```

The script rejects a modified local repository, fast-forwards from
`origin/main`, verifies that the LibreChat image is pinned by digest, and
validates the Compose file. It then displays the exact commit and requests
`DEPLOY <commit>` before pulling images and reconciling containers. After that
confirmation, it also replaces the former explicit Bedrock model list with a
catalog generated from AWS metadata for the account and region. The catalog
retains text models with streaming responses and active system inference
profiles, including `global.*` profiles when AWS publishes them. This operation
does not subscribe to any Marketplace model, create any Marketplace endpoint,
or invoke inference. AWS may still deny a model for which the account is not
eligible. In that case, the operator must resolve that denial in AWS before
using the model.

The script also refuses to overwrite an HTTPS-publishing container that belongs
to another Compose project. This is specifically the case for the current
manual deployment named `multimodel`: it must first be explicitly replaced
using the clean-install procedure below.

The current manual stack can be replaced with a clean LibreChat installation by
using `rebuild-librechat-on-ec2.sh`. This script does not affect AWS resources,
the Elastic IP, or containers unrelated to LibreChat. It only removes the
`multimodel-*` containers and LibreChat data directories under
`/opt/aws-multimodel-llm-platform/data` after the requested exact confirmation.

From the EC2 instance, after merging the pull request and validating the commit
on `main`, run for example:

```sh
sudo ./scripts/rebuild-librechat-on-ec2.sh \
  --domain "chat.example.com" \
  --acme-email "your-address@example.com" \
  --image "registry.librechat.ai/danny-avila/librechat@sha256:c5db3331b845e1f289f8d04c0c77936c4bbe372f76730a804abc1c37e44d23a9" \
  --open-registration
```

The domain name is supplied only at runtime and is never stored in Git. The
Elastic IP remains unchanged. The `--open-registration` option is reserved for
creating the first local account. Immediately after creating it, close
registration:

```sh
sudo ./scripts/close-librechat-registration-on-ec2.sh
```

Subsequent deployments use `deploy-librechat-on-ec2.sh`. None of these scripts
runs Terraform: `terraform plan` and `terraform apply` remain manual operator
actions.
