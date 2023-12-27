cp -rf AMD-APP-SDK-v2.9.1-lnx64/lib/x86_64/* /usr/lib/
cp -rf AMD-APP-SDK-v2.9.1-lnx64/include/CL /usr/include/
ldconfig

apt-get install  git libcurl4-openssl-dev pkg-config libjansson-dev yasm libncurses5-dev libtool automake autoconf libncurses5 -y

sh autogen.sh
 ./configure --prefix=$PWD/bfgminer-binaries --enable-opencl  --enable-cpumining


