const applicationDatabase = db.getSiblingDB('LibreChat');

applicationDatabase.createUser({
  user: process.env.MONGO_APP_USERNAME,
  pwd: process.env.MONGO_APP_PASSWORD,
  roles: [
    {
      role: 'readWrite',
      db: 'LibreChat',
    },
  ],
});
