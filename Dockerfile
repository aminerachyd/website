FROM docker.io/polinux/mkdocs:1.5.2 AS builder

WORKDIR /tmp

COPY . /tmp

RUN pip install mkdocs-material mkdocs-awesome-pages-plugin

RUN mkdocs build

FROM nginx:1.17.1-alpine

COPY --from=builder /tmp/site /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]
