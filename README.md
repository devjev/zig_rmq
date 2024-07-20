Zig wrapper around rabbitmq-c
=============================

Statically linked wrapper around [rabbitmq-c](https://github.com/alanxz/rabbitmq-c/tree/v0.14.0).

> [!TIP]
> Build scripts are written for a Unix system. Not sure when I will get to
> updating them to work on Windows.

Dependencies
------------

- Zig 0.13
- CMake (to build rabbitmq-c)
- OpenSSL (for OpenSSL support by rabbitmq-c)

How to build
------------

1. Build the librabbitmq static library. This can be done via the corresponding
   script: `$ sh build-rabbitmq.sh`. It is enough to do this once and the
   results will be placed in the `libs/` directory.
2. Run `$ zig build`.

License
-------

See [LICENSE](LICENSE).
