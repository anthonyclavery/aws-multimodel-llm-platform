# GitHub human approval

A pull request targeting `main` must pass three checks: `Validate Terraform`,
`Validate runtime assets`, and `Human approval`.

After the two technical validations, the final check waits on the GitHub
Actions page. Using the repository owner's account, open the relevant run,
choose `Review deployments`, select the `human-approval` environment, then
choose `Approve and deploy`.

This action is the human decision recorded in GitHub. Once it succeeds, the
`Merge approved pull request` job automatically merges the reviewed pull
request into `main`. It runs only after the approval and both technical
validations have succeeded. The merge API is pinned to the reviewed pull request
SHA, so GitHub refuses the merge if the branch changed after the workflow began.
