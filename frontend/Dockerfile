FROM node:20 as build
WORKDIR /app

COPY package*.json ./
RUN npm install

ARG VITE_API_URL
ARG VITE_API_KEY
ENV VITE_API_URL=$VITE_API_URL
ENV VITE_API_KEY=$VITE_API_KEY

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html

# Create a script to inject environment variables
RUN echo '#!/bin/sh' > /docker-entrypoint.d/30-inject-env.sh && \
    echo 'envsubst < /usr/share/nginx/html/index.html > /tmp/index.html && mv /tmp/index.html /usr/share/nginx/html/index.html' >> /docker-entrypoint.d/30-inject-env.sh && \
    chmod +x /docker-entrypoint.d/30-inject-env.sh

EXPOSE 80
