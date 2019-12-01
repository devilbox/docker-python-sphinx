###
### BUILDER
###
ARG ALPINE
ARG PYTHON
FROM python:${PYTHON}-alpine${ALPINE} as builder-dev

# General requirements
RUN set -x \
	&& apk add --no-cache \
		gcc \
		musl-dev \
		linux-headers

RUN set -x \
	&& pip install \
		sphinx \
		sphinx-autobuild \
		virtualenv

RUN set -x \
	&& find / -type d -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find / -type f -name '*.pyc' -print0 | xargs -0 -n1 rm -rf


###
### DEVELOPMENT
###
FROM python:${PYTHON}-alpine${ALPINE} as dev
ARG PYTHON

# Labels
# https://github.com/opencontainers/image-spec/blob/master/annotations.md
#LABEL "org.opencontainers.image.created"=""
#LABEL "org.opencontainers.image.version"=""
#LABEL "org.opencontainers.image.revision"=""
LABEL "maintainer"="cytopia <cytopia@everythingcli.org>"
LABEL "org.opencontainers.image.authors"="cytopia <cytopia@everythingcli.org>"
LABEL "org.opencontainers.image.url"="https://github.com/devilbox/docker-python-sphinx"
LABEL "org.opencontainers.image.documentation"="https://github.com/devilbox/docker-python-sphinx"
LABEL "org.opencontainers.image.source"="https://github.com/devilbox/docker-python-sphinx"
LABEL "org.opencontainers.image.vendor"="devilbox"
LABEL "org.opencontainers.image.licenses"="MIT"
LABEL "org.opencontainers.image.ref.name"="${PYTHON}-dev"
LABEL "org.opencontainers.image.title"="Python ${PYTHON}-dev"
LABEL "org.opencontainers.image.description"="Python ${PYTHON}-dev"

# Copy artifacts from builder
COPY --from=builder-dev /usr/local/lib/python${PYTHON}/site-packages/ /usr/local/lib/python${PYTHON}/site-packages/
COPY --from=builder-dev /usr/local/bin/ /usr/local/bin/

# User and default dir
RUN set -x \
	&& addgroup -g 1000 devilbox \
	&& adduser -h /home/devilbox -G devilbox -D -u 1000 devilbox \
	&& mkdir -p /shared/httpd \
	&& chmod 0755 /shared/httpd \
	&& chown devilbox:devilbox /shared/httpd

# Start script
COPY data/start.sh /start.sh

# Start
ENTRYPOINT ["/start.sh"]
