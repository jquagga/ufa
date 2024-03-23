FROM debian:12-slim@sha256:ccb33c3ac5b02588fc1d9e4fc09b952e433d0c54d8618d0ee1afadf1f3cf2455 AS builder
WORKDIR /app/git
ARG TARGETPLATFORM
RUN apt-get update && \
    apt-get install --no-install-recommends -y build-essential git devscripts debhelper tcl8.6-dev autoconf \
    python3-dev python3-venv python3-setuptools libz-dev openssl \
    libboost-system-dev libboost-program-options-dev libboost-regex-dev python3-wheel python3-pip python3-build \
    libboost-filesystem-dev patchelf wget ca-certificates apt-rdepends
RUN git clone --depth 1 https://github.com/flightaware/piaware_builder /app/git && \
    bash sensible-build.sh bookworm
WORKDIR /app/git/package-bookworm
RUN export DEB_BUILD_OPTIONS=noautodbgsym && \
    dpkg-buildpackage -b --no-sign

# This uses apt-rdepends to download the dependencies for readsb, removes the libc/gcc ones provided by distroless
# and puts it all in the /newroot directory to be copied over to the stage 2 image
WORKDIR /dpkg
RUN mv /app/git/*.deb  .
RUN apt-get download -y --no-install-recommends $(apt-rdepends libboost-program-options1.74.0 libboost-regex1.74.0 zlib1g coreutils libexpat1 |grep -v "^ ") && \
    apt-get download -y --no-install-recommends net-tools iproute2 tclx8.4 tcl8.6 tcllib tcl-tls itcl3 libtcl8.6 && \
    rm libc* libgcc* gcc* 
WORKDIR /newroot
RUN dpkg --unpack -R --force-all --root=/newroot /dpkg/

FROM gcr.io/distroless/cc-debian12:nonroot@sha256:548d3e91231ffc84c1543da0b63e4063defc1f9620aa969e7f5abfafeb35afbe
COPY --from=builder /newroot /


ENTRYPOINT ["/usr/bin/piaware"]