FROM node:24.13.0 AS build
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
RUN npm ci
COPY apps/api apps/api
COPY db db
RUN npm run build

FROM node:24.13.0 AS runtime
WORKDIR /app
COPY package.json package-lock.json ./
COPY apps/api/package.json apps/api/package.json
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=build /app/apps/api/dist apps/api/dist
COPY db db
USER node
WORKDIR /app/apps/api
EXPOSE 3000
CMD ["sh", "-c", "node dist/src/migrate.js && node dist/src/seed.js && node dist/src/main.js"]
