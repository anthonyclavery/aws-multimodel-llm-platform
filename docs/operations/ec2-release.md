# Publication LibreChat depuis l'EC2

Les évolutions de LibreChat sont appliquées par l'opérateur, directement depuis
l'EC2. L'agent prépare, évalue et vérifie les changements, mais ne lance jamais
le script de déploiement à la place de l'opérateur.

Depuis le clone du dépôt sur l'EC2, lancer :

```sh
./scripts/deploy-librechat-on-ec2.sh
```

Le script refuse un dépôt local modifié, récupère `origin/main` en
fast-forward, vérifie que l'image LibreChat est figée par digest et valide le
fichier Compose. Il affiche ensuite le commit exact et demande
`DEPLOY <commit>` avant le téléchargement des images et la réconciliation des
conteneurs. Il retire aussi, après cette confirmation, l'ancienne liste
explicite de modèles Bedrock de l'environnement runtime afin que LibreChat
utilise ses modèles serverless compatibles connus. Cette opération ne souscrit
à aucun modèle Marketplace et ne crée aucun endpoint Marketplace.

Le script refuse aussi d'écraser un conteneur publiant HTTPS qui appartient à
un autre projet Compose. C'est précisément le cas du déploiement manuel actuel
nommé `multimodel` : il faut d'abord le remplacer explicitement par la
procédure d'installation vierge ci-dessous.

La pile manuelle actuelle peut être remplacée par une installation LibreChat
vierge au moyen de `rebuild-librechat-on-ec2.sh`. Ce script ne touche ni aux
ressources AWS, ni à l'Elastic IP, ni aux conteneurs non liés à LibreChat. Il
supprime uniquement les conteneurs `multimodel-*` et les répertoires de données
LibreChat sous `/opt/aws-multimodel-llm-platform/data` après la confirmation
exacte demandée.

Depuis l'EC2, après fusion de la PR et validation du commit sur `main`, lancer
par exemple :

```sh
sudo ./scripts/rebuild-librechat-on-ec2.sh \
  --domain "chat.example.com" \
  --acme-email "ton-adresse@example.com" \
  --image "registry.librechat.ai/danny-avila/librechat@sha256:c5db3331b845e1f289f8d04c0c77936c4bbe372f76730a804abc1c37e44d23a9" \
  --open-registration
```

Le nom de domaine est fourni uniquement à l'exécution et n'est jamais enregistré
dans Git. L'Elastic IP reste inchangée. L'option `--open-registration` est
réservée à la création du premier compte local. Immédiatement après cette
création, fermer les inscriptions :

```sh
sudo ./scripts/close-librechat-registration-on-ec2.sh
```

Les déploiements suivants utilisent `deploy-librechat-on-ec2.sh`. Aucun de ces
scripts ne lance Terraform : `terraform plan` et `terraform apply` restent des
actions manuelles de l'opérateur.
