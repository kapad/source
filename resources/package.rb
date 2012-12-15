actions :build
default_action :build

attribute :source, :kind_of => [String], :regex => /(ftp|git|https?):\/\/[^\/]+\/.*/
attribute :source_type, :kind_of => [String], :equal_to => ["git", "tarball"], :required => true
attribute :creates, :kind_of => [String], :required => true
attribute :checksum, :kind_of => [String], :regex => "[0-9a-fA-F]{64}", :default => nil
attribute :ref, :kind_of => String, :default => nil
attribute :build_command, :default => "make install", :kind_of => String
