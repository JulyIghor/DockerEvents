FROM alpine:latest
LABEL maintainer="julyighor@gmail.com"

COPY docker_events.sh /usr/bin/

RUN apk add --no-cache curl bash jq

ENTRYPOINT "docker_events.sh"
