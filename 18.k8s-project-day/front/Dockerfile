# Dockerfile
FROM node:14 AS builder
COPY . /app
WORKDIR /app/src
RUN sed -i 's/http:\/\/localhost:3000/\$BASE_URL/' config.json
WORKDIR /app
RUN npm install
RUN npm run build

FROM nginx:1.17
WORKDIR /usr/share/nginx/html
COPY --from=builder /app/dist .
COPY start_nginx.sh /
RUN chmod +x /start_nginx.sh
ENTRYPOINT ["/start_nginx.sh"]