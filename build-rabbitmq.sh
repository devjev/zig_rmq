# Prepare the installation path.
rm -rf libs && mkdir libs
pushd libs
rm -rf librabbitmq && mkdir librabbitmq
cd librabbitmq
PREFIX="$(pwd)"
popd

# Build rabbitmq
cd rabbitmq-c
rm -rf build && mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DBUILD_STATIC_LIBS=ON -DBUILD_EXAMPLES=OFF -DBUILD_SHARED_LIBS=OFF -DENABLE_SSL_SUPPORT=ON ..
cmake --build . --config Release --target install
