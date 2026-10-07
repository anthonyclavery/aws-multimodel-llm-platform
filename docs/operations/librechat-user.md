# Identité AWS dédiée LibreChat

`librechat_user` est l'identité locale réservée à ce projet. Elle n'a pas de
droits directs sur l'infrastructure : sa seule autorisation d'administration
est d'endosser le rôle Terraform dédié au projet. Elle peut aussi gérer ses
propres clés d'accès pour permettre une rotation sans revenir au compte
administrateur global.

## Première configuration locale

Après application de Terraform, créer une clé d'accès pour `librechat_user`
dans la console IAM. Ne pas créer de mot de passe de console et ne jamais
placer la clé dans Git, dans un fichier du projet, ou dans une commande copiée
dans l'historique shell.

Configurer ensuite la clé de manière interactive dans WSL :

```sh
aws configure --profile librechat-user-source
```

Récupérer l'ARN du rôle affiché par Terraform, puis créer le profil qui assume
ce rôle :

```sh
aws configure set role_arn '<ARN affiché dans librechat_terraform_operator_role_arn>' --profile librechat-user
aws configure set source_profile librechat-user-source --profile librechat-user
aws configure set region eu-central-1 --profile librechat-user
aws configure set output json --profile librechat-user
aws sts get-caller-identity --profile librechat-user
```

La dernière commande doit afficher l'ARN du rôle
`aws-multimodel-llm-platform-v0-terraform-operator`, et non celui de
`librechat_user` ni celui de `musical_madness_user`.

Utiliser ensuite explicitement ce profil pour les opérations locales du projet,
par exemple :

```sh
./scripts/terraform-plan.sh --profile librechat-user
./scripts/verify-backup-recovery.sh --profile librechat-user
./scripts/start-v0-instance.sh --profile librechat-user
```

## Portée de l'identité

Le rôle autorise uniquement le backend Terraform de cet environnement, les
services nécessaires à la plateforme dans `eu-central-1`, AWS Backup, SSM sur
l'instance du projet, les secrets dont le nom commence par le préfixe du
projet, et les rôles IAM portant le même préfixe. Il n'accorde ni accès aux
ressources applicatives de Musical Madness, ni souscription Marketplace, ni
droits d'administration généraux.

La clé source est une clé longue durée. La faire tourner dès qu'elle est
exposée, perdue ou devenue inutile. AWS recommande les identifiants temporaires
lorsqu'ils sont disponibles ; ici, la clé ne permet que l'endossement d'un rôle
propre au projet.
