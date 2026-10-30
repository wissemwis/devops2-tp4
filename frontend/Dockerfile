# ---- 1. Dépendances ----
FROM node:22-alpine AS deps
WORKDIR /app
# .npmrc : registre npm à utiliser (votre Nexus, partie 2)
COPY package.json package-lock.json .npmrc ./
RUN npm ci

# ---- Tests unitaires, de composant et d'intégration (jamais livré en production) ----
FROM deps AS test
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY . .
CMD ["npm", "run", "test:unit"]

# ---- Tests de bout en bout : image officielle Playwright (navigateurs inclus) ----
FROM mcr.microsoft.com/playwright:v1.64.1-noble AS e2e
WORKDIR /app
# .npmrc : registre npm à utiliser (votre Nexus, partie 2)
COPY package.json package-lock.json .npmrc ./
RUN npm ci
COPY . .
CMD ["npm", "run", "test:e2e"]

# ---- 2. Build ----
FROM node:22-alpine AS builder
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# ---- 3. Image d'exécution (sortie "standalone", sans node_modules complet) ----
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3000 \
    HOSTNAME=0.0.0.0
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
USER node
EXPOSE 3000
CMD ["node", "server.js"]
