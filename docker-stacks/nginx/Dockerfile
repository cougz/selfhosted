FROM nginx:alpine

RUN apk add --no-cache curl bash openssl jq

# Install acme.sh without specifying an email
RUN curl https://get.acme.sh | sh
RUN ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80 443

ENTRYPOINT ["/start.sh"]