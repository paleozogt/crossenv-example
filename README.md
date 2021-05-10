# Python crossenv Example

This project shows an example of cross-compiling python packages using [crossenv](https://pypi.org/project/crossenv/).  The Dockerfile builds cross packages and then puts them into a container of the same architecture.

To build it, specify an architecture:

```
$ ./build.sh arm64v8
...
Successfully tagged crossenv_example:arm64v8
```

While building the cross image is done entirely on the host arch (presumably amd64),
to run it you'll need to setup qemu:
```
$ docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Then run the image:
```
$ docker run --rm -it crossenv_example:arm64v8
# uname -m
aarch64
# pip freeze
numpy==1.19.5
# python -c 'import numpy; print(numpy)'
<module 'numpy' from '/venv/lib/python3.7/site-packages/numpy/__init__.py'>
```
