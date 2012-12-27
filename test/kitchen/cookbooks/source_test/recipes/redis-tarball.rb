include_recipe "source"
source_package "redis" do
    source_type "tarball"
    source "http://redis.googlecode.com/files/redis-2.6.7.tar.gz"
    build_command "make install"
    creates "/usr/local/sbin/redis-server"
end
