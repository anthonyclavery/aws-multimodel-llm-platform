# Maintenance de l'image EC2

L'AMI de l'instance V0 est volontairement figée par la variable `ami_id`.
Une source d'AMI "la plus récente" ferait remplacer l'instance au prochain
`terraform apply`, y compris lorsqu'une modification sans rapport est faite.

Pour mettre à jour l'image, prévoir une fenêtre de maintenance, sauvegarder
les données EBS, mettre à jour `ami_id`, examiner un plan qui annonce le
remplacement de l'EC2, puis appliquer cette opération explicitement. Ne pas
utiliser cette procédure pour une modification ordinaire de l'infrastructure.
