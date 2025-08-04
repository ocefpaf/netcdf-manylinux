set -euo pipefail

# We build curl + openssl from source due to https://github.com/Unidata/netcdf4-python/issues/1179
# yum -y curl-devel

# perl is needed for openssl
yum -y install wget zlib-devel perl-IPC-Cmd

build_openssl() {
    wget https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz
    tar -xzvf openssl-${OPENSSL_VERSION}.tar.gz

    pushd openssl-${OPENSSL_VERSION}
      ./config shared -fPIC shared --prefix=${BUILD_PREFIX} --libdir=lib
      make -j$(nproc)
      make install_sw install_ssldirs
    popd
}

build_curl() {
    flags="--prefix=${BUILD_PREFIX} --disable-ldap --with-openssl=${BUILD_PREFIX} --without-zstd --without-libpsl"
    wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz
    tar -xzvf curl-${CURL_VERSION}.tar.gz
    pushd curl-${CURL_VERSION}
      ./configure ${flags}
      make -j$(nproc)
      make install
    popd
}

build_libaec(){
    # The URL includes a hash, so it needs to change if the version does
    wget  https://gitlab.dkrz.de/-/project/117/uploads/dc5fc087b645866c14fa22320d91fb27/libaec-${AEC_VERSION}.tar.gz
    tar zxf libaec-${AEC_VERSION}.tar.gz

    echo "Building & installing libaec"
    pushd libaec-${AEC_VERSION}
      ./configure
      make -j$(nproc)
      make install
    popd
}

build_hdf5() {
    # This seems to be needed to find libsz.so.2
    ldconfig

    #                           Remove trailing .*, to get e.g. 'major.minor' ↓
    HDF5_TAG="hdf5_${HDF5_VERSION}"
    wget "https://github.com/HDFGroup/hdf5/archive/refs/tags/${HDF5_TAG}.tar.gz"
    tar -xzvf hdf5_${HDF5_VERSION}.tar.gz
    pushd hdf5-${HDF5_TAG}
      chmod u+x autogen.sh

      echo "Configuring, building & installing HDF5 ${HDF5_VERSION} to ${BUILD_PREFIX}"
      ./configure --prefix ${BUILD_PREFIX} --enable-build-mode=production --with-szlib
      make -j$(nproc)
      make install
    popd
}

build_netcdf() {
    NETCDF_SRC=netcdf-c-${NETCDF_VERSION}
    NETCDF_BLD=netcdf-build

    wget https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_VERSION}.tar.gz
    tar -xzvf v${NETCDF_VERSION}.tar.gz

      cmake ${NETCDF_SRC} -B ${NETCDF_BLD} \
          -DENABLE_NETCDF4=on \
          -DENABLE_HDF5=on \
          -DCMAKE_INSTALL_LIBDIR=lib \
          -DENABLE_DAP=on \
          -DENABLE_TESTS=off \
          -DENABLE_PLUGIN_INSTALL=off \
          -DBUILD_SHARED_LIBS=on \
          -DCMAKE_BUILD_TYPE=Release

      cmake --build ${NETCDF_BLD} \
          --target install
}

clean_up(){
  # Clean up to reduce the size of the Docker image.
  echo "Cleaning up unnecessary files"
  rm -rf hdf5-${HDF5_VERSION} \
         libaec-${AEC_VERSION} \
         hdf5-${HDF5_VERSION}.tar.gz \
         libaec-${AEC_VERSION}.tar.gz \
         ${NETCDF_SRC}

  # Can't execute this with our own curl in the path.
  # yum -y erase wget zlib-devel perl-IPC-Cmd
}

pushd /tmp
build_openssl
build_curl
build_libaec
build_hdf5
build_netcdf
clean_up
popd
