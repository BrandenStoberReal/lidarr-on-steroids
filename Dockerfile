FROM --platform=linux/amd64 docker.io/library/node:16-alpine as deemix

RUN echo "Building for TARGETPLATFORM=linux/amd64 | BUILDPLATFORM=linux/amd64"

# Default packages
RUN apk add --no-cache git jq python3 make gcc musl-dev g++ wget curl tidyhtml musl-locales musl-locales-lang flac gcc ffmpeg imagemagick opus-tools opustags libc-dev py3-pip nodejs npm yt-dlp && \
    rm -rf /var/lib/apt/lists/*

# Clone deemix & process
RUN git clone --recurse-submodules https://gitlab.com/RemixDev/deemix-gui.git
WORKDIR deemix-gui
RUN case "linux/amd64" in \
        "linux/amd64") \
            jq '.pkg.targets = ["node16-alpine-x64"]' ./server/package.json > tmp-json ;; \
        "linux/arm64") \
            jq '.pkg.targets = ["node16-alpine-arm64"]' ./server/package.json > tmp-json ;; \
        *) \
            echo "Platform bowser fnaf jumpscare not supported" && exit 1 ;; \
    esac && \
    mv tmp-json /deemix-gui/server/package.json
RUN yarn install-all
# Patching deemix: see issue https://github.com/youegraillot/lidarr-on-steroids/issues/63
RUN sed -i 's/const channelData = await dz.gw.get_page(channelName)/let channelData; try { channelData = await dz.gw.get_page(channelName); } catch (error) { console.error(`Caught error ${error}`); return [];}/' ./server/src/routes/api/get/newReleases.ts
RUN yarn dist-server
RUN mv /deemix-gui/dist/deemix-server /deemix-server

FROM ghcr.io/hotio/lidarr:pr-plugins-1.4.1.3564

LABEL maintainer="brandens"

ENV DEEMIX_SINGLE_USER=true
ENV AUTOCONFIG=true
ENV CLEAN_DOWNLOADS=true
ENV PUID=1000
ENV PGID=1000

# flac2mp3
RUN apk add --no-cache ffmpeg && \
    rm -rf /var/lib/apt/lists/*
COPY lidarr-flac2mp3/root/usr /usr

# deemix
COPY --from=deemix /deemix-server /deemix-server
RUN chmod +x /deemix-server
VOLUME ["/config_deemix", "/downloads"]
EXPOSE 6595

# arl-watch
RUN apk add --no-cache inotify-tools && \
    rm -rf /var/lib/apt/lists/*

COPY root /
RUN chmod +x /etc/services.d/*/run && \
    chmod +x /usr/local/bin/*.sh

VOLUME ["/config", "/music"]
EXPOSE 6595 8686

# Tidal freya client
RUN npm install -g miraclx/freyr-js

# Tidal python packages
RUN pip install --upgrade --no-cache-dir yq pyacoustid requests pylast mutagen r128gain tidal-dl

# Tidal integration packages
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/testing atomicparsley
RUN apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community beets

# Make SMA Dir
RUN mkdir -p "/usr/local/sma"

# Clone sickbeard repo
RUN git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git "/usr/local/sma"

# Create sickbeard config dir
RUN mkdir -p "/usr/local/sma/config"
RUN touch "/usr/local/sma/config/sma.log"
RUN chgrp users "/usr/local/sma/config/sma.log"
RUN chmod g+w "/usr/local/sma/config/sma.log"

# Install sickbeard python dependencies
RUN python3 -m pip install --upgrade pip
RUN pip3 install -r "/usr/local/sma/setup/requirements.txt"

# Create services directory
RUN mkdir -p /custom-services.d

# Download services
RUN echo "Download QueueCleaner service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/services/QueueCleaner -o /custom-services.d/QueueCleaner

RUN echo "Download AutoConfig service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/AutoConfig.service.bash -o /custom-services.d/AutoConfig

RUN echo "Download Video service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/Video.service.bash -o /custom-services.d/Video

RUN echo "Download Tidal Video Downloader service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/TidalVideoDownloader.bash -o /custom-services.d/TidalVideoDownloader

RUN echo "Download Audio service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/Audio.service.bash -o /custom-services.d/Audio

RUN echo "Download AutoArtistAdder service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/AutoArtistAdder.bash -o /custom-services.d/AutoArtistAdder

RUN echo "Download UnmappedFilesCleaner service..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/UnmappedFilesCleaner.bash -o /custom-services.d/UnmappedFilesCleaner

RUN mkdir -p /config/extended
RUN echo "Download Script Functions..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/universal/functions.bash -o /config/extended/functions

RUN echo "Download PlexNotify script..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/PlexNotify.bash -o /config/extended/PlexNotify.bash 

RUN echo "Download SMA config..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/sma.ini -o /config/extended/sma.ini 

RUN echo "Download Tidal config..."
RUN curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/tidal-dl.json" -o /config/extended/tidal-dl.json

RUN echo "Download LyricExtractor script..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/LyricExtractor.bash -o /config/extended/LyricExtractor.bash

RUN echo "Download ArtworkExtractor script..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/ArtworkExtractor.bash -o /config/extended/ArtworkExtractor.bash

RUN echo "Download Beets Tagger script..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/BeetsTagger.bash -o /config/extended/BeetsTagger.bash

RUN echo "Download Beets config..."
RUN curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-config.yaml" -o /config/extended/beets-config.yaml

RUN echo "Download Beets lidarr config..."
RUN curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-config-lidarr.yaml" -o /config/extended/beets-config-lidarr.yaml

RUN echo "Download beets-genre-whitelist.txt..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/beets-genre-whitelist.txt -o /config/extended/beets-genre-whitelist.txt

RUN echo "Download Extended config..."
RUN curl https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/lidarr/extended.conf -o /config/extended.conf
RUN chmod 777 /config/extended.conf

# Adjust permissions
RUN chmod 777 -R /config/extended
RUN chmod 777 -R /root