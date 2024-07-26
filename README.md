Zig wrapper around rabbitmq-c
=============================

Statically linked wrapper around [rabbitmq-c](https://github.com/alanxz/rabbitmq-c/tree/v0.14.0)
with a comfortable Zig interface.

> [!WARNING]
> Library is still work in progress. Most of it is incomplete. Read the code 
> and try it out, if you are looking for ideas how to use rabbitmq-c in your
> Zig projects, but don't use this for anything else.


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


Lessons learned so far
----------------------

### Zig has a huge ecosystem

Zig's ability to seamlessly integrate C projects (or even any project that can
be compiled to a static library for that matter) is a **superpower**. Especially 
`zig translate-c` is very helpful to understand how the C project fits into the
Zig world.

A few points that I learned for myself.

- Linking in system libraries is currently difficult. I couldn't figure out how
  to properly do it, if the source file with the `main` function is anywhere
  other than in [src](src/). I couldn't get the include and lib paths to be 
  recognized when the main file was in a subpath in of [src](src/), for 
  example.
- The best way to include a C/C++/Fortran/etc. project in your Zig project is to
  `git submodule` it, build it as a static library and `@cImport(...)` it. Of
  course this would require you actually reading the project's readme and
  figuring out how to build it properly and where the includes and libs are in
  the end. For an example of how I did it with [rabbitmq-c](https://github.com/alanxz/rabbitmq-c/tree/v0.14.0) see
  [build-rabbitmq.sh](build-rabbitmq.sh). 
- Even though the integration is seamless, the APIs of the imported C project
  are still C APIs. This means that the approach how the code is structured and 
  how memory management is handled will be different to that of Zig and you will 
  likely spend some time writing wrapper code to make it more convenient to use.
  This repo being a case in point.

### Building it

See [build.zig](build.zig) for details on how to ensure the static library is
properly included. The neat way to do it (as far as I can tell at this point) 
is:

#### 1. Define your library modules separately

This will be used in any executable files you want to produce (see below).

```zig
const lib_mod = b.createModule(.{
    .root_source_file = b.path("src/lib.zig"),
});
```

#### 2. Link in the static library dependencies into your modules

```zig
lib_mod.addIncludePath(b.path("libs/librabbitmq/include"));
lib_mod.addLibraryPath(b.path("libs/librabbitmq/lib"));
lib_mod.addObjectFile(b.path("libs/librabbitmq/lib/librabbitmq.a"));
```

Of course, this requires for the the above paths and files to be there. My
preferred way of doing this, is having a dedicated (and gitignored) directory in
project root where the static builds are installed (as you can see in
[build-rabbitmq.sh](build-rabbitmq.sh):

```sh 
# prefix is <project root>/libs
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" ..
cmake --build . --config Release --target install
```

#### 3. Add the module created in (1) to the executable you want to produce

```zig
const consumer_exe = b.addExecutable(.{
    .name = "queue_consumer",
    .root_source_file = b.path("src/examples/queue_consumer.zig"),
    .target = target,
    .optimize = optimize,
});
consumer_exe.root_module.addImport("zig_rmq", lib_mod);
b.installArtifact(consumer_exe);
```

### Ownership, not a straitjacket

Getting your program to handle resources (like memory) nicely is surprisingly 
easy in Zig. Especially compared to Rust, where you have to fight the borrow 
checker, clone everyting or do box gymnastics of arbitrary depth.


See [src/lib.zig](src/lib.zig):

```zig
pub const Connection = struct {
    alloc: *const std.mem.Allocator, // keep a pointer to the allocator here
    conn: c.amqp_connection_state_t,
    socket: ?*c.amqp_socket_t,
    hostname: [:0]const u8,

    // ...
    
    pub fn deinit(self: *const @This()) void {
        // (some code before)
        self.alloc.free(self.hostname); // use it to deallocate at deinit
    }
};
```


License
-------

See [LICENSE](LICENSE).
