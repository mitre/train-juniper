# frozen_string_literal: true

# This file exists simply to record the version number of the plugin.
# It is kept in a separate file, so that your gemspec can load it and
# learn the current version without loading the whole plugin.  Also,
# many CI servers can update this file when "version bumping".

module TrainPlugins
  module Juniper
    VERSION = '0.6.2'
  end
end
