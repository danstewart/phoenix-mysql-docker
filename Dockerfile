# syntax=docker/dockerfile:1.2

# Base elixir image uses debian buster
FROM elixir:1.12.3

LABEL version="0.0.1"

ENV PHX_VERSION 1.6.0
ENV NODE_MAJOR 14.17.6

# Disable auto-cleanup after install:
RUN rm /etc/apt/apt.conf.d/docker-clean
ENV DEBIAN_FRONTEND=noninteractive

RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -
RUN --mount=type=cache,target=/var/cache/apt,id=apt apt-get update && apt-get -y upgrade && apt-get -y install nodejs inotify-tools mariadb-client

RUN useradd --create-home app
USER app

ENV APP_HOME /home/app/phoenix
RUN mkdir --parents ${APP_HOME}
WORKDIR ${APP_HOME}

COPY entrypoint.sh /home/app
COPY ./src/ ${APP_HOME}

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix archive.install hex phx_new ${PHX_VERSION} --force

EXPOSE 4000
ENTRYPOINT [ ]
CMD [ "/home/app/entrypoint.sh" ]
