FROM node:24.16.0-alpine@sha256:21f403ab171f2dc89bad4dd69d7721bfd15f084ccb46cdd225f31f2bc59b5c9a

WORKDIR /srv/app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY server.mjs sync-pricing.mjs pricing.json ./

USER node
EXPOSE 8080

CMD ["node", "server.mjs"]
