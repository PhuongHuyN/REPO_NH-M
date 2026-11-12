FROM node:20-alpine
WORKDIR /app
COPY api/package*.json api/
RUN cd api && npm ci --omit=dev
COPY api ./api
COPY web ./web
COPY simulator ./simulator
ENV PORT=3000
EXPOSE 3000
CMD ["node", "api/src/server.js"]
