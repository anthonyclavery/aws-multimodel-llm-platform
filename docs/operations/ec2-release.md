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
conteneurs.

Le script refuse aussi d'écraser un conteneur publiant HTTPS qui appartient à
un autre projet Compose. C'est précisément le cas du déploiement manuel actuel
nommé `multimodel`. Sa reprise exige un plan de migration distinct incluant une
sauvegarde MongoDB, le nom de domaine, le certificat Caddy et une stratégie de
retour arrière.

Le premier déploiement géré nécessite toujours `bootstrap-v0.sh`, exécuté avec
un nom de domaine validé, une adresse ACME et une référence d'image contenant
un digest `@sha256:`. Le script de publication sert aux évolutions suivantes.
