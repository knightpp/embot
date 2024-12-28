FROM elixir:1.18-alpine AS builder

RUN apk --no-cache add ca-certificates

ENV MIX_ENV="prod"
ENV ENABLE_FS_VIDEO="1"

WORKDIR /src

COPY mix.exs . 
COPY mix.lock . 

RUN mix deps.get --only prod
RUN mix deps.compile

COPY config/ config/ 
COPY lib/ lib/

RUN mix release

FROM alpine:3

RUN adduser --no-create-home --uid 1000 --disabled-password bot
RUN apk --no-cache add libgcc libcrypto3 libncursesw libstdc++ zlib

USER bot:bot
COPY --from=builder --chown=bot:bot /src/_build/prod/rel/embot /app/embot

WORKDIR /app/embot
ENTRYPOINT [ "/app/embot/bin/embot", "start"]
