ARG from

FROM ${from}

ARG mount
ARG http_proxy
ARG https_proxy

ENV MOUNT ${mount}
ENV HTTP_PROXY ${http_proxy}
ENV HTTPS_PROXY ${https_proxy}
ENV http_proxy ${http_proxy}
ENV https_proxy ${https_proxy}

ARG update
ARG install
ARG pkgs

RUN ${update} && ${install} ${pkgs}

ARG repo

COPY . /opt/${repo}
