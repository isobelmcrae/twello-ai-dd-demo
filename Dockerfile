# syntax=docker/dockerfile:1

# Install dependencies from the lockfile.
FROM node:22.23.5-alpine AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# Build the Next.js standalone server.
FROM node:22.23.5-alpine AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production runtime: standalone server plus the checked-in migrations.
FROM node:22.23.5-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    HOSTNAME=0.0.0.0 \
    PORT=3000
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static
COPY --from=build --chown=node:node /app/migrations ./migrations
COPY --from=build --chown=node:node /app/scripts/migrate.mjs ./scripts/migrate.mjs
EXPOSE 3000
USER node
CMD ["sh", "-c", "node scripts/migrate.mjs && exec node server.js"]
