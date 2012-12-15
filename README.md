# source cookbook
A cookbook containing LWRP for easy installation of source packages. DRY.

# Requirements
While not a strict dependency, you probably want to `include_recipe "build-essential"`. This cookbook doesn't have any recipes and therefor can't do this for you.

# Usage
Download and compile a simple source package from github:

    include_recipe "build-essential"
    inlcude_recipe "git"
    
    source_package "jzmq" do
        source_type "git"
        source "https://github.com/zeromq/jzmq.git"
        build_command "./autogen.sh && ./configure && ./make install"
        creates "/usr/local/share/java/zmq.jar"
    end

and from tarball:

    source_package "redis"
        source_type "tarball"
        source "http://redis.googlecode.com/files/redis-2.6.7.tar.gz"
        build_command "make install"
        creates "/usr/local/sbin/redis-server"
    end


# Attributes

# Author

Author:: avishai@fewbytes.com
