name             "source"
maintainer       "Fewbytes"
maintainer_email "chef@fewbytes.com"
license          "All rights reserved"
description      "Installs/builds source packages"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.2.0"

depends         "build-essential"
suggests         "git"
