FROM nginx:1.25.0-alpine

RUN apk update \
    && apk add wget vim \
    && apk add tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
    && apk add nodejs \
    && apk add npm && \
    npm install -g yarn

COPY ./README.html /usr/share/nginx/html/index.html
COPY ./docker/default.conf /etc/nginx/conf.d/default.conf