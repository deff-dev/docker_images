FROM        ubuntu

LABEL       author="Vitaliy Kotov" maintainer="vitaliy.kotov2017@mail.ru"

LABEL       org.opencontainers.image.source="https://github.com/deff-dev/docker_images"
LABEL       org.opencontainers.image.licenses=MIT

LABEL      org.opencontainers.image.description="Изменена ссылка на github репозиторий"

ENV         DEBIAN_FRONTEND=noninteractive

RUN         dpkg --add-architecture i386 \
                                && apt update \
                                && apt upgrade -y \
                                && apt install -y tar curl gcc g++ lib32gcc-s1 libgcc1 libcurl4-gnutls-dev:i386 libssl1.1:i386 libcurl4:i386 lib32tinfo6 libt>
                                && useradd -m -d /home/container container

USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
