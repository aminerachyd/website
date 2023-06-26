FROM docker.io/peaceiris/mdbook:v0.4.30 AS builder

WORKDIR /tmp

COPY . /tmp

RUN mdbook build

FROM nginx:1.17.1-alpine

COPY --from=builder /tmp/book /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]