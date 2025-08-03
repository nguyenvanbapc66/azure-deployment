FROM node:20
WORKDIR /app

# Copy package*.json first, then install dependencies, then copy the rest of the code
# This way, if only your source code changes, Docker won't reinstall dependencies
COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

CMD ["node", "dist/server.js"]
EXPOSE 5000