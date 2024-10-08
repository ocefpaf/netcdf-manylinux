set -euo pipefail

# perl is needed for openssl
# yum -y install wget zlib-devel curl-devel
yum -y install wget zlib-devel perl-IPC-Cmd

build_libaec(){
    # The URL includes a hash, so it needs to change if the version does
    wget  https://gitlab.dkrz.de/k202009/libaec/uploads/45b10e42123edd26ab7b3ad92bcf7be2/libaec-${AEC_VERSION}.tar.gz
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
    wget "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-${HDF5_VERSION%.*}/hdf5-${HDF5_VERSION}/src/hdf5-${HDF5_VERSION}.tar.gz"
    tar -xzvf hdf5-${HDF5_VERSION}.tar.gz
    pushd hdf5-${HDF5_VERSION}
      chmod u+x autogen.sh

      echo "Configuring, building & installing HDF5 ${HDF5_VERSION} to ${BUILD_PREFIX}"
      ./configure --prefix ${BUILD_PREFIX} --enable-build-mode=production --with-szlib
      make -j$(nproc)
      make install
    popd
}

build_openssl() {
    wget http://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
    tar -xzvf openssl-${OPENSSL_VERSION}.tar.gz
    pushd openssl-${OPENSSL_VERSION}
      ./config shared -fPIC shared --prefix=${BUILD_PREFIX} --libdir=lib
      make -j$(nproc)
      make install
    popd
}
 
build_curl() {
    flags="--prefix=${BUILD_PREFIX} --disable-ldap --with-ssl --without-zstd"
    wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz
    tar -xzvf curl-${CURL_VERSION}.tar.gz
    pushd curl-${CURL_VERSION}
      ./configure ${flags}
      make -j$(nproc)
      make install
    popd
}

build_netcdf() {
    netcdf_url=https://github.com/Unidata/netcdf-c
    NETCDF_SRC=netcdf-c
    NETCDF_BLD=netcdf-build

    # We are building from lastest b/c # it has fix for setting CURL path to find SSL certificates.
    git clone https://github.com/Unidata/netcdf-c ${NETCDF_SRC}
    # git clone ${netcdf_url} -b ${NETCDF_VERSION} ${NETCDF_SRC}

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
