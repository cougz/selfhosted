FROM nginx:alpine

RUN apk add --no-cache curl bash openssl jq

# Install acme.sh
RUN curl https://get.acme.sh | sh

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80 443

ENTRYPOINT ["/start.sh"]