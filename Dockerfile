FROM nginx:1.17.1-alpine

COPY index.html /usr/share/nginx/html

CMD ["nginx", "-g", "daemon off;"]