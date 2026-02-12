   sudo yum install gcc -y -q
   sudo yum install git -y -q
   sudo yum install gcc-c++ -y
   sudo yum install ncurses-devel -y
   sudo yum install -y automake
   sudo yum install -y autoconf
   sudo yum install -y libtool
   sudo yum install -y make

   git clone https://github.com/mellanox/sockperf
   cd sockperf/
   ./autogen.sh
   ./configure --prefix=
   make            # this is slow, may take several minutes
   sudo make install

   