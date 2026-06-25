FROM node:22
WORKDIR /app
COPY . .
RUN yarn install
RUN yarn build
EXPOSE 8080
USER node
CMD ["node", "dist/main.js"]
