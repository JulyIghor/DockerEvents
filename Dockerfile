FROM alpine:latest
LABEL maintainer="julyighor@gmail.com"

COPY docker_events.sh /usr/bin/

RUN apk add --no-cache bash jq curl

ENTRYPOINT ["bash", "-c", "docker_events.sh"]
