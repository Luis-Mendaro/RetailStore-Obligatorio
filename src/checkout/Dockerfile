FROM node:22
WORKDIR /app
COPY . .
RUN yarn install
RUN yarn build
EXPOSE 8080
CMD ["node", "dist/main.js"]
