FROM elixir:1.17-alpine AS builder

RUN apk --no-cache add ca-certificates

ENV MIX_ENV="prod"
WORKDIR /src

COPY mix.exs . 
COPY mix.lock . 

RUN mix deps.get --only prod

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
