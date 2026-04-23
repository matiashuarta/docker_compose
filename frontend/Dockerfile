FROM nginx:alpine

# .template extension tells nginx to run envsubst on startup
# nginx reads from /etc/nginx/templates/ and outputs to /etc/nginx/conf.d/
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html