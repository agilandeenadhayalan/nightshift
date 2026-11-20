FROM node:24.13.0 AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/mobile/package.json apps/mobile/package.json
COPY audio/package.json audio/package.json
COPY packages/contracts/package.json packages/contracts/package.json
COPY packages/backend-domain/package.json packages/backend-domain/package.json
RUN npm ci
COPY turbo.json .node-version ./
COPY apps/api apps/api
COPY packages/contracts packages/contracts
COPY packages/backend-domain packages/backend-domain
COPY db db
RUN npm run build

FROM node:24.13.0 AS runtime
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
COPY apps/mobile/package.json apps/mobile/package.json
COPY audio/package.json audio/package.json
COPY packages/contracts/package.json packages/contracts/package.json
COPY packages/backend-domain/package.json packages/backend-domain/package.json
RUN npm ci --omit=dev --workspace=@nightshift/api --include-workspace-root=false && npm cache clean --force
COPY --from=build /app/apps/api/dist apps/api/dist
COPY --from=build /app/packages/backend-domain/dist packages/backend-domain/dist
COPY db db
USER node
WORKDIR /app/apps/api
EXPOSE 3000
CMD ["sh", "-c", "node dist/src/migrate.js && node dist/src/seed.js && exec node dist/src/main.js"]
