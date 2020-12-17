FROM oryxdevmcr.azurecr.io/public/oryx/build:github-actions AS main

ENV ORYX_BUILDIMAGE_TYPE="jamstack" \
    PATH="/opt/nodejs/lts/bin:/usr/local/go/bin:$PATH"

COPY --from=support-files-image-for-build /tmp/oryx/ /tmp
RUN oryx prep --skip-detection --platforms-and-versions nodejs=12 \
    && echo "jamstack" > /opt/oryx/.imagetype \
    && . /tmp/build/__nodeVersions.sh \
    && /tmp/images/installPlatform.sh nodejs $NODE14_VERSION \
    && cd /opt/nodejs \
    && ln -s $NODE14_VERSION 14 \
    && ln -s 14 lts \
    && npm install -g lerna \
    && . /tmp/build/__goVersions.sh \
    && downloadedFileName="go${GO_VERSION}.linux-amd64.tar.gz" \
    && curl -SLsO https://golang.org/dl/$downloadedFileName \
    && tar -C /usr/local -xzf $downloadedFileName \
    && rm -rf $downloadedFileName
