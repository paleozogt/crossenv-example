ARG ARCH
ARG PYTHON_VER_SHORT=3.7
ARG PYTHON_VER_FULL=$PYTHON_VER_SHORT.4
FROM debian:buster-slim as builder

ARG ARCH
ARG TRIPLET
ARG PACKAGE_ARCH
ARG PYTHON_VER_SHORT
ARG PYTHON_VER_FULL
ARG MAKEFLAGS=-j8

# build tools
RUN apt-get update && apt-get install -y \
        build-essential \
        wget \
  && rm -rf /var/lib/apt/lists/*

# cross-compiler and arch repo
RUN if [ $(gcc -dumpmachine) != "$TRIPLET" ]; then \
        . /etc/os-release \
     && dpkg --add-architecture $PACKAGE_ARCH \
     && echo "deb [arch=$PACKAGE_ARCH] http://deb.debian.org/debian $VERSION_CODENAME main" >> /etc/apt/sources.list \
     && apt-get update && apt-get install -y \
            g++-$TRIPLET \
     && rm -rf /var/lib/apt/lists/* \
    ; fi

# python dependencies
RUN apt-get update && apt-get install -y \
    libexpat1-dev \
    libexpat1-dev:$PACKAGE_ARCH \
    libssl-dev \
    libssl-dev:$PACKAGE_ARCH \
    libffi-dev \
    libffi-dev:$PACKAGE_ARCH \
    zlib1g-dev \
    zlib1g-dev:$PACKAGE_ARCH \
  && rm -rf /var/lib/apt/lists/*

# build python
ARG BUILD_PYTHON_PATH=/usr/local
RUN wget https://www.python.org/ftp/python/$PYTHON_VER_FULL/Python-$PYTHON_VER_FULL.tgz \
 && tar xvf *.tgz && rm *.tgz \
 && cd Python* \
 && ./configure \
        --prefix=$BUILD_PYTHON_PATH \
        --enable-ipv6 \
        --enable-unicode=ucs4 \
        --enable-shared \
        --with-system-ffi \
        --with-system-expat \
        --with-dbmliborder=gdbm \
 && make $MAKEFLAGS \
 && make install \
 && cd .. \
 && rm -rf Python*
RUN cd $BUILD_PYTHON_PATH/bin \
 && ln -s python3 python
ENV LD_LIBRARY_PATH=$BUILD_PYTHON_PATH/lib

# host python
ARG HOST_PYTHON_PATH=/build/host_python
RUN wget https://www.python.org/ftp/python/$PYTHON_VER_FULL/Python-$PYTHON_VER_FULL.tgz \
 && tar xvf *.tgz && rm *.tgz \
 && cd Python* \
 && ./configure \
        --prefix=$HOST_PYTHON_PATH \
        --host=$TRIPLET \
        --build=$(gcc -dumpmachine) \
        --without-ensurepip \
        --enable-unicode=ucs4 \
        ac_cv_buggy_getaddrinfo=no \
        ac_cv_file__dev_ptmx=yes \
        ac_cv_file__dev_ptc=no \
 && make $MAKEFLAGS \
 && make install \
 && cd .. \
 && rm -rf Python*

# cross env
ARG CROSS_VENV=/build/venv
RUN $BUILD_PYTHON_PATH/bin/pip3 install -U pip \
 && $BUILD_PYTHON_PATH/bin/pip3 install crossenv \
 && $BUILD_PYTHON_PATH/bin/python3 -m crossenv \
    $HOST_PYTHON_PATH/bin/python3 \
    $CROSS_VENV

# pip install packages
ADD requirements.txt /
RUN $CROSS_VENV/bin/build-pip install -r requirements.txt
RUN $CROSS_VENV/bin/cross-pip install -r requirements.txt
RUN rm requirements.txt

# deploy cross-compiled packages into ordinary venv
RUN $BUILD_PYTHON_PATH/bin/python3 -m venv /venv
RUN cp -nR $CROSS_VENV/cross/lib/python$PYTHON_VER_SHORT/site-packages/* /venv/lib/python$PYTHON_VER_SHORT/site-packages/

##############################################
FROM $ARCH/python:$PYTHON_VER_FULL-slim-buster as prod
COPY --from=builder /venv /venv
ENV PATH="/venv/bin:$PATH"
ENTRYPOINT ["/bin/bash"]
