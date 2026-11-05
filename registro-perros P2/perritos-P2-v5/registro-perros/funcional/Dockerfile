# ---- Etapa 1: compilar el release ----
FROM elixir:1.18-alpine AS compilar
RUN apk add --no-cache build-base git
WORKDIR /app
ENV MIX_ENV=prod
RUN mix local.hex --force && mix local.rebar --force

# primero sólo las dependencias, para que Docker las reutilice
# (mix.lock* : si todavía no existe, no truena)
COPY mix.exs mix.lock* ./
RUN mix deps.get --only prod && mix deps.compile

COPY lib lib
RUN mix release

# ---- Etapa 2: sólo ejecutar ----
FROM elixir:1.18-alpine
RUN apk add --no-cache tzdata
WORKDIR /app
COPY --from=compilar /app/_build/prod/rel/funcional ./
EXPOSE 4000
CMD ["bin/funcional", "start"]
