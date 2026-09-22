# --- API NestJS (build depuis la racine du workspace pour inclure packages/database) ---
FROM node:22-slim
RUN corepack enable && corepack prepare pnpm@9.15.9 --activate \
 && apt-get update && apt-get install -y --no-install-recommends openssl ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
ENV PUPPETEER_SKIP_DOWNLOAD=true

# Manifests d'abord (cache des couches)
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY packages/database/package.json packages/database/package.json
COPY crm-api/package.json crm-api/package.json
RUN pnpm install --prod=false

# Sources
COPY packages/database packages/database
COPY crm-api crm-api

# Client Prisma + build API (DATABASE_URL requis pour prisma generate, pas besoin d'être joignable)
ENV DATABASE_URL="postgresql://crm:crm@localhost:5432/crm?schema=public"
RUN pnpm --filter @crm/database run db:generate \
 && pnpm --filter @crm/api run build

EXPOSE 4000
# Applique les migrations puis démarre l'API
CMD ["sh","-c","pnpm --filter @crm/database exec prisma migrate deploy && node crm-api/dist/main.js"]
