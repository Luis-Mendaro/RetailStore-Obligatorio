FROM node:22
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
ENV PORT=8080
EXPOSE 8080
USER node
CMD ["node", "dist/app.js"]
