FROM node:20-alpine

WORKDIR /app

COPY package.json ./
COPY src ./src
COPY public ./public
COPY programs ./programs
COPY templates ./templates
COPY scripts ./scripts

EXPOSE 3000

CMD ["npm", "start"]
