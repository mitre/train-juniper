# frozen_string_literal: true

require 'shellwords'

module TrainPlugins
  module Juniper
    # Windows-specific proxy handling using plink.exe
    # This pattern is used by various Ruby projects for Windows SSH support,
    # including hglib.rb (Mercurial) and follows Net::SSH::Proxy::Command patterns
    module WindowsProxy
      # Check if plink.exe is available on Windows
      # @return [Boolean] true if plink.exe is found in PATH
      def plink_available?
        return false unless Gem.win_platform?

        ENV['PATH'].split(File::PATH_SEPARATOR).any? do |path|
          File.exist?(File.join(path, 'plink.exe'))
        end
      end

      # Build plink.exe proxy command for Windows bastion authentication
      # @param bastion_host [String] Bastion hostname
      # @param user [String] Username for bastion
      # @param port [Integer] Port for bastion
      # @param password [String] Password for bastion
      # @return [String] Complete plink command string
      def build_plink_proxy_command(bastion_host, user, port, password)
        parts = []
        parts << 'plink.exe'
        parts << '-batch' # Non-interactive mode
        parts << '-ssh'   # Force SSH protocol (not telnet)
        parts << '-pw'
        parts << Shellwords.escape(password)

        if port && port != 22
          parts << '-P'
          parts << port.to_s
        end

        parts << "#{user}@#{bastion_host}"
        parts << '-nc'
        parts << '%h:%p' # Netcat mode for proxying

        parts.join(' ')
      end
    end
  end
end
