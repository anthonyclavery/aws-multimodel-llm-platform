# Sauvegarde et restauration

AWS Backup protège chaque jour l'instance EC2 et son volume EBS chiffré dans le
vault `aws-multimodel-llm-platform-v0-vault`. La conservation est de 30 jours.
La sauvegarde planifiée est indépendante de LibreChat et reste valable lorsque
l'instance est arrêtée la nuit.

## Contrôle quotidien

Depuis WSL, vérifier qu'un point de récupération EC2 chiffré et récent existe :

```sh
./scripts/verify-backup-recovery.sh --profile librechat-user
```

La commande échoue si le dernier point est absent, non chiffré, ou âgé de plus
de 26 heures. Elle ne modifie aucune ressource AWS.

## Restauration non destructive

Une restauration AWS Backup crée une nouvelle AMI, une nouvelle instance et de
nouveaux volumes. Elle ne remplace pas l'instance de production existante.

En cas d'incident, ouvrir AWS Backup dans `eu-central-1`, choisir
**Protected resources**, sélectionner l'instance LibreChat puis le dernier
point de récupération terminé. Choisir **Restore** et conserver le VPC, le
sous-réseau, le groupe de sécurité et le profil d'instance du projet. Ne pas
associer l'Elastic IP de production à l'instance restaurée pendant le contrôle.

Attendre l'état `COMPLETED`, puis vérifier l'instance restaurée via SSM. Tester
LibreChat sur son adresse privée ou une adresse de test. Confirmer la présence
des données sous `/opt/aws-multimodel-llm-platform/data`, le démarrage des
conteneurs, et la possibilité de se connecter avec le compte LibreChat.

Après validation explicite seulement, préparer le basculement de l'Elastic IP
vers l'instance restaurée. Cette étape interrompt le trafic de production et
doit être faite dans une fenêtre de maintenance. L'ancienne instance et son
Elastic IP ne doivent jamais être supprimés avant une validation fonctionnelle
complète.

AWS Backup ne restaure pas le user-data EC2. Ce projet n'en dépend pas : le
déploiement et les scripts sont versionnés dans Git, et les données applicatives
restent sur le volume sauvegardé.

## Exercice de restauration

Un exercice complet crée temporairement une instance et des volumes facturés.
Il doit être demandé et validé séparément. À l'issue de l'exercice, arrêter puis
supprimer uniquement les ressources de test identifiées pendant la restauration,
après avoir confirmé qu'elles ne portent pas l'Elastic IP de production.
