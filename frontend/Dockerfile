FROM node:20-alpine AS dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS build
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup -S taskly && adduser -S taskly -G taskly
COPY --from=build /app/public ./public
COPY --from=build --chown=taskly:taskly /app/.next/standalone ./
COPY --from=build --chown=taskly:taskly /app/.next/static ./.next/static
USER taskly
EXPOSE 3000
CMD ["node", "server.js"]
