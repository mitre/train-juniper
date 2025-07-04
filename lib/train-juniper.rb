# frozen_string_literal: true

# This file is known as the "entry point."
# This is the file Train will try to load if it
# thinks your plugin is needed.

# The *only* thing this file should do is setup the
# load path, then load plugin files.

# Next two lines simply add the path of the gem to the load path.
# This is not needed when being loaded as a gem; but when doing
# plugin development, you may need it.  Either way, it's harmless.
libdir = __dir__
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# It's traditional to keep your gem version in a separate file, so CI can find it easier.
require 'train-juniper/version'

# A train plugin has three components: Transport, Connection, and Platform.
# Transport acts as the glue.
require 'train-juniper/transport'
require 'train-juniper/platform'
require 'train-juniper/connection'
