FROM alpine:3.24.2

RUN apk add --no-cache git-daemon \
    && addgroup -S -g 65532 clac \
    && adduser -S -D -H -u 65532 -G clac clac

USER 65532:65532
WORKDIR /git
ENTRYPOINT ["git"]
CMD ["daemon", "--help"]

