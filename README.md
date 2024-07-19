Zig wrapper around rabbitmq-c
=============================

Small quality-of-life Zig wrapper around rabbitmq-c, which is linked as a
systems library (i.e., not statically build and linked in).

> [!WARNING]
> I can't for the life of me figure out how to structure the project
> into folders, while also linking in a system library without
> hardcoding the include and library paths. Maybe something for
> the future or when I have enough patience to build rabbitmq-c 
> statically.

Dependencies
------------

- Zig 0.13
- librabbitmq (i.e., rabbitmq-c)

License
-------

See [LICENSE](LICENSE).
