# LibreChat credential encoding migration

LibreChat v0.8.8 requires `CREDS_KEY` as 32 bytes represented by 64 lowercase
hexadecimal characters and `CREDS_IV` as 16 bytes represented by 32 lowercase
hexadecimal characters. Earlier platform versions stored the same bytes in
Base64.

Before upgrading an existing instance, run the migration from the local WSL
checkout with the approved AWS profile:

```sh
./scripts/migrate-librechat-credentials-to-hex.sh --profile aws-multimodel-llm
```

The script changes only the encoding of the existing bytes. It does not rotate
the encryption material and does not print it. After the operator-confirmed
secret update, synchronize the repository on the EC2 instance, then run:

```sh
./scripts/refresh-librechat-credentials-on-ec2.sh
```

Only then run the approved LibreChat image upgrade using the normal deployment
script. New installations generate hexadecimal credentials directly.
