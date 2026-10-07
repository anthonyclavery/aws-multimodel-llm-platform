# GitHub human approval

A pull request targeting `main` must pass three checks: `Validate Terraform`,
`Validate runtime assets`, and `Human approval`.

After the two technical validations, the final check waits on the GitHub
Actions page. Using the repository owner's account, open the relevant run,
choose `Review deployments`, select the `human-approval` environment, then
choose `Approve and deploy`.

This action is the human decision recorded in GitHub. It does not merge
anything automatically. Before merging, the agent verifies that the approval,
the two technical validations, and the pull request SHA all correspond to the
same state.
