FROM nginx:1.25.0-alpine

RUN apk update \
    && apk add wget vim \
    && apk add tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

COPY ./README.html /usr/share/nginx/html/index.html
COPY ./docker/default.conf /etc/nginx/conf.d/default.conf