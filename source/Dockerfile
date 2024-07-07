FROM        registry.gitlab.steamos.cloud/steamrt/sniper/platform:latest-container-runtime-public-beta

LABEL       author="Vitaliy Kotov" maintainer="vitaliy.kotov2017@mail.ru"

LABEL       org.opencontainers.image.source="https://github.com/deff-dev/docker_images"
LABEL       org.opencontainers.image.licenses=MIT

LABEL      org.opencontainers.image.description="Изменена ссылка на github репозиторий"

ENV         DEBIAN_FRONTEND=noninteractive

RUN          useradd -m -d /home/container container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
