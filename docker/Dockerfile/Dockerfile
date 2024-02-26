# FROM bitnami/node:20.11.0
# FROM node:latest
# FROM node:lts-slim

FROM node:lts-alpine3.19
LABEL maintainer="Md. Redwan Hossain"
WORKDIR /node-app
COPY . .
RUN apk update && apk add bash && apk add libc6-compat && apk add curl
RUN bash -c "npm clean-install"
RUN bash -c "npm run build"
EXPOSE 3020
CMD ["node", "./dist/app.js"]