ARG ARCH
ARG PYTHON_VER_SHORT=3.7
ARG PYTHON_VER_FULL=$PYTHON_VER_SHORT.4
FROM $ARCH/python:$PYTHON_VER_FULL-slim-buster as cross
FROM python:$PYTHON_VER_FULL-slim-buster as builder

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
    libexpat1-dev:$PACKAGE_ARCH \
    libssl-dev:$PACKAGE_ARCH \
    libffi-dev:$PACKAGE_ARCH \
    zlib1g-dev:$PACKAGE_ARCH \
  && rm -rf /var/lib/apt/lists/*

# cross python
ARG CROSS_PYTHON_PATH=/opt/$TRIPLET
COPY --from=cross /usr/local/bin/python*                        $CROSS_PYTHON_PATH/bin/
COPY --from=cross /usr/local/lib/libpython*                     $CROSS_PYTHON_PATH/lib/
COPY --from=cross /usr/local/lib/python$PYTHON_VER_SHORT        $CROSS_PYTHON_PATH/lib/python$PYTHON_VER_SHORT
COPY --from=cross /usr/local/include/python${PYTHON_VER_SHORT}m $CROSS_PYTHON_PATH/include/python${PYTHON_VER_SHORT}m

# cross env
ARG CROSS_VENV=/build/venv
RUN pip3 install -U pip \
 && pip3 install crossenv \
 && python3 -m crossenv \
      --cc $TRIPLET-gcc \
      --cxx $TRIPLET-g++ \
      $CROSS_PYTHON_PATH/bin/python3 \
      $CROSS_VENV

# pip install packages
ADD requirements.txt /
RUN $CROSS_VENV/bin/build-pip install -r requirements.txt
RUN LDFLAGS=-L$CROSS_PYTHON_PATH/lib \
    $CROSS_VENV/bin/cross-pip install -r requirements.txt
RUN rm requirements.txt

# deploy cross-compiled packages into ordinary venv
RUN python3 -m venv /venv
RUN cp -nR $CROSS_VENV/cross/lib/python$PYTHON_VER_SHORT/site-packages/* /venv/lib/python$PYTHON_VER_SHORT/site-packages/

##############################################
FROM cross as prod
COPY --from=builder /venv /venv
ENV PATH="/venv/bin:$PATH"
ENTRYPOINT ["/bin/bash"]
