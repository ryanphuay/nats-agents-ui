FROM node:22-alpine

WORKDIR /app
COPY package.json agent.ts tsconfig.json ./
RUN npm install

ENV HOME=/home/node
USER node
CMD ["npm", "start"]
