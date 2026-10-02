# Approbation humaine GitHub

Une pull request vers `main` doit satisfaire trois contrôles : `Validate
Terraform`, `Validate runtime assets` et `Human approval`.

Après les deux validations techniques, le dernier contrôle attend dans la page
GitHub Actions. Avec le compte propriétaire du dépôt, ouvrir le run concerné,
choisir `Review deployments`, sélectionner l'environnement `human-approval`,
puis choisir `Approve and deploy`.

Cette action est la décision humaine enregistrée dans GitHub. Elle ne fusionne
rien automatiquement. Avant de fusionner, l'agent vérifie que l'approbation,
les deux validations techniques et le SHA de la pull request correspondent
tous au même état.
