#
# Cookbook Name:: source
# Recipe:: default
#
# Copyright (C) 2012 YOUR_NAME
# 
# All rights reserved - Do Not Redistribute
#
include_recipe "build-essential"
if node.platform_family == "debian"
  package "pkg-config" # missing on build-essential
  package "libtool"
end
