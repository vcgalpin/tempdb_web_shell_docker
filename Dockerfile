FROM ubuntu:25.10

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    git \
    libgmp-dev \
    libpcre3-dev \
    libpq-dev \
    locales \
    m4 \
    opam \
    patch \
    pkg-config \
    postgresql \
    postgresql-client \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Put PostgreSQL tools on PATH
RUN PGVER="$(ls /usr/lib/postgresql | sort -V | tail -1)" \
 && ln -sf "/usr/lib/postgresql/${PGVER}/bin/initdb" /usr/local/bin/initdb \
 && ln -sf "/usr/lib/postgresql/${PGVER}/bin/pg_ctl" /usr/local/bin/pg_ctl \
 && ln -sf "/usr/lib/postgresql/${PGVER}/bin/pg_isready" /usr/local/bin/pg_isready \
 && ln -sf "/usr/lib/postgresql/${PGVER}/bin/psql" /usr/local/bin/psql

RUN useradd -m -s /bin/bash linksuser \
 && mkdir -p /opt/app /opt/postgres-data /opt/scripts \
 && chown -R linksuser:linksuser /home/linksuser /opt/app /opt/postgres-data /opt/scripts

USER linksuser
WORKDIR /home/linksuser

RUN opam init --disable-sandboxing -a --bare \
 && opam switch create 5.1.1 ocaml-base-compiler.5.1.1

ENV OPAMSWITCH=5.1.1

RUN opam exec --switch=5.1.1 -- opam update \
 && opam exec --switch=5.1.1 -- opam install -y postgresql links.0.9.8 links-postgresql.0.9.8

ARG APP_REPO_URL=https://github.com/vcgalpin/xps_dcc_app
ARG APP_REPO_BRANCH=main
ARG APP_REPO_COMMIT=unknown

LABEL tempdb_web_shell.repo_url="${APP_REPO_URL}"
LABEL tempdb_web_shell.repo_branch="${APP_REPO_BRANCH}"
LABEL tempdb_web_shell.repo_commit="${APP_REPO_COMMIT}"

WORKDIR /opt/app
RUN git clone --branch "${APP_REPO_BRANCH}" --depth 1 "${APP_REPO_URL}" /opt/app

USER root
COPY entrypoint.sh /opt/scripts/entrypoint.sh
RUN chmod 755 /opt/scripts/entrypoint.sh \
 && chown linksuser:linksuser /opt/scripts/entrypoint.sh

USER linksuser
WORKDIR /opt/app

ENV APP_START_COMMAND="linx --config=config.0.9.8 src/startXPS.links"

EXPOSE 8081

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]

