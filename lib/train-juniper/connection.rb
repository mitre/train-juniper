# Connection definition for Juniper Train plugin.

# This plugin provides SSH connectivity to Juniper network devices,
# enabling InSpec to connect to and inspect Juniper routers and switches.
# Key capabilities:
# * SSH authentication to Juniper devices
# * Platform detection for JunOS devices
# * Command execution via SSH with prompt handling
# * File operations for configuration inspection

# Base Train transport functionality
require "train"
require "logger"

# Juniper-specific platform detection
require "train-juniper/platform"

# Using Train's SSH transport for connectivity

module TrainPlugins
  module Juniper
    # Main connection class for Juniper devices
    class Connection < Train::Plugins::Transport::BaseConnection
      # Include Juniper-specific platform detection
      include TrainPlugins::Juniper::Platform

      attr_reader :ssh_session

      def initialize(options)
        # Configure SSH connection options for Juniper devices
        # Support environment variables for authentication (following train-vsphere pattern)
        @options = options.dup
        @options[:host] ||= ENV['JUNIPER_HOST']
        @options[:user] ||= ENV['JUNIPER_USER']  
        @options[:password] ||= ENV['JUNIPER_PASSWORD']
        @options[:port] ||= ENV['JUNIPER_PORT']&.to_i || 22
        @options[:timeout] ||= ENV['JUNIPER_TIMEOUT']&.to_i || 30
        
        # Proxy/bastion environment variables (Train standard)
        @options[:bastion_host] ||= ENV['JUNIPER_BASTION_HOST']
        @options[:bastion_user] ||= ENV['JUNIPER_BASTION_USER']
        @options[:bastion_user] ||= 'root'  # Default only if no env var
        @options[:bastion_port] ||= ENV['JUNIPER_BASTION_PORT']&.to_i || 22
        @options[:proxy_command] ||= ENV['JUNIPER_PROXY_COMMAND']
        
        @options[:keepalive] = true
        @options[:keepalive_interval] = 60
        
        # Setup logger
        @logger = @options[:logger] || Logger.new(STDOUT, level: Logger::WARN)
        
        # JunOS CLI prompt patterns
        @cli_prompt = /[%>$#]\s*$/
        @config_prompt = /[%#]\s*$/
        
        # Log connection info without exposing credentials
        safe_options = @options.reject { |k,v| [:password, :proxy_command, :key_files].include?(k) }
        @logger.debug("Juniper connection initialized with options: #{safe_options.inspect}")
        @logger.debug("Environment: JUNIPER_BASTION_USER=#{ENV['JUNIPER_BASTION_USER']} -> bastion_user=#{@options[:bastion_user]}")
        
        # Validate proxy configuration early (Train standard)
        validate_proxy_options
        
        super(@options)
        
        # Establish SSH connection to Juniper device (unless in mock mode)
        @logger.debug("Attempting to connect to Juniper device...")
        connect unless @options[:mock]
      end
      
      # Secure string representation (never expose credentials)
      def to_s
        "#<#{self.class.name}:0x#{object_id.to_s(16)} @host=#{@options[:host]} @user=#{@options[:user]}>"
      end
      
      def inspect
        to_s
      end

      # File operations for Juniper configuration files
      # Supports reading configuration files and operational data
      def file_via_connection(path)
        # For Juniper devices, "files" are typically configuration sections
        # or operational command outputs rather than traditional filesystem paths
        JuniperFile.new(self, path)
      end

      # File transfer operations (following network device pattern)
      # Network devices don't support traditional file upload/download
      # Use run_command() for configuration management instead
      def upload(locals, remote)
        raise NotImplementedError, "#{self.class} does not implement #upload() - network devices use command-based configuration"
      end

      def download(remotes, local)
        raise NotImplementedError, "#{self.class} does not implement #download() - use run_command() to retrieve configuration data"
      end

      # Execute commands on Juniper device via SSH
      def run_command_via_connection(cmd)
        return mock_command_result(cmd) if @options[:mock]
        
        begin
          # Ensure we're connected
          connect unless connected?
          
          @logger.debug("Executing command: #{cmd}")
          
          # Execute command via SSH session
          output = @ssh_session.exec!(cmd)
          
          @logger.debug("Command output: #{output}")
          
          # Format JunOS result
          format_junos_result(output, cmd)
        rescue => e
          @logger.error("Command execution failed: #{e.message}")
          # Handle connection errors gracefully
          CommandResult.new("", 1, e.message)
        end
      end
      
      private
      
      # Establish SSH connection to Juniper device
      def connect
        return if connected?
        
        begin
          # Use direct SSH connection (network device pattern)
          require 'net/ssh'
          
          @logger.debug("Establishing SSH connection to Juniper device")
          
          ssh_options = {
            port: @options[:port] || 22,
            password: @options[:password],
            timeout: @options[:timeout] || 30,
            verify_host_key: :never,
            keepalive: @options[:keepalive],
            keepalive_interval: @options[:keepalive_interval]
          }
          
          # Add SSH key authentication if specified
          if @options[:key_files]
            ssh_options[:keys] = Array(@options[:key_files])
            ssh_options[:keys_only] = @options[:keys_only]
          end
          
          # Add bastion host support if configured
          if @options[:bastion_host]
            require 'net/ssh/proxy/jump'
            
            # Build proxy jump string from bastion options
            bastion_user = @options[:bastion_user] || 'root'
            bastion_port = @options[:bastion_port] || 22
            
            proxy_jump = if bastion_port == 22
              "#{bastion_user}@#{@options[:bastion_host]}"
            else
              "#{bastion_user}@#{@options[:bastion_host]}:#{bastion_port}"
            end
            
            @logger.debug("Using bastion host: #{proxy_jump}")
            
            # Set up automated password authentication via SSH_ASKPASS
            bastion_password = @options[:bastion_password] || @options[:password]  # Use explicit bastion password or fallback
            if bastion_password
              @ssh_askpass_script = create_ssh_askpass_script(bastion_password)
              ENV['SSH_ASKPASS'] = @ssh_askpass_script
              ENV['SSH_ASKPASS_REQUIRE'] = 'force'  # Force use of SSH_ASKPASS even with terminal
              @logger.debug("Configured SSH_ASKPASS for automated bastion authentication")
            end
            
            ssh_options[:proxy] = Net::SSH::Proxy::Jump.new(proxy_jump)
          end
          
          @logger.debug("Connecting to #{@options[:host]}:#{@options[:port]} as #{@options[:user]}")
          
          # Direct SSH connection 
          @ssh_session = Net::SSH.start(@options[:host], @options[:user], ssh_options)
          @logger.debug("SSH connection established successfully")
          
          # Configure JunOS session for automation
          test_and_configure_session
          
        rescue => e
          @logger.error("SSH connection failed: #{e.message}")
          
          # Provide helpful error messages for common authentication issues
          if (e.message.include?("Permission denied") || e.message.include?("command failed")) && @options[:bastion_host]
            raise Train::TransportError, <<~ERROR
              Failed to connect to Juniper device #{@options[:host]} via bastion #{@options[:bastion_host]}: #{e.message}
              
              SSH bastion authentication with passwords is not supported due to ProxyCommand limitations.
              Please use one of these alternatives:
              
              1. SSH Key Authentication (Recommended):
                 Use --key-files option to specify SSH private key files
                 
              2. SSH Agent:
                 Ensure your SSH agent has the required keys loaded
                 
              3. Direct Connection:
                 Connect directly to the device if network allows (remove bastion options)
              
              For more details, see: https://mitre.github.io/train-juniper/troubleshooting/#bastion-authentication
            ERROR
          else
            raise Train::TransportError, "Failed to connect to Juniper device #{@options[:host]}: #{e.message}"
          end
        end
      end
      
      # Check if SSH connection is active
      def connected?
        !@ssh_session.nil?
      rescue
        false
      end
      
      # Test connection and configure JunOS session  
      def test_and_configure_session
        @logger.debug("Testing SSH connection and configuring JunOS session")
        
        # Test connection first
        result = @ssh_session.exec!('echo "connection test"')
        @logger.debug("SSH connection test successful")
        
        # Optimize CLI for automation
        @ssh_session.exec!('set cli screen-length 0')
        @ssh_session.exec!('set cli screen-width 0') 
        @ssh_session.exec!('set cli complete-on-space off') if @options[:disable_complete_on_space]
        
        @logger.debug("JunOS session configured successfully")
      rescue => e
        @logger.warn("Failed to configure JunOS session: #{e.message}")
      end
      
      # Format JunOS command results (from implementation plan)
      def format_junos_result(output, cmd)
        # Parse JunOS-specific error patterns
        if junos_error?(output)
          CommandResult.new("", 1, output)
        else
          CommandResult.new(clean_output(output, cmd), 0, "")
        end
      end
      
      # Check for JunOS error patterns (from implementation plan)
      def junos_error?(output)
        JUNOS_ERROR_PATTERNS.any? { |pattern| output.match?(pattern) }
      end
      
      # Clean command output
      def clean_output(output, cmd)
        # Handle nil output gracefully
        return "" if output.nil?
        
        # Remove command echo and prompts
        lines = output.to_s.split("\n")
        lines.reject! { |line| line.strip == cmd.strip }
        
        # Remove JunOS prompt patterns from the end
        while lines.last && lines.last.strip.match?(/^[%>$#]+\s*$/)
          lines.pop
        end
        
        lines.join("\n")
      end
      
      # Validate proxy configuration options (Train standard)
      def validate_proxy_options
        # Cannot use both bastion_host and proxy_command simultaneously
        if @options[:bastion_host] && @options[:proxy_command]
          raise Train::ClientError, "Cannot specify both bastion_host and proxy_command"
        end
      end
      
      
      # Create temporary SSH_ASKPASS script for automated password authentication
      def create_ssh_askpass_script(password)
        require 'tempfile'
        
        script = Tempfile.new(['ssh_askpass', '.sh'])
        script.write("#!/bin/bash\necho '#{password}'\n")
        script.close
        File.chmod(0755, script.path)
        
        @logger.debug("Created SSH_ASKPASS script at #{script.path}")
        script.path
      end
      
      # Generate SSH proxy command for bastion host using ProxyJump (-J)
      def generate_bastion_proxy_command(bastion_user, bastion_port)
        args = ['ssh']
        
        # SSH options for connection
        args += ['-o', 'UserKnownHostsFile=/dev/null']
        args += ['-o', 'StrictHostKeyChecking=no']
        args += ['-o', 'LogLevel=ERROR']
        args += ['-o', 'ForwardAgent=no']
        
        # Use ProxyJump (-J) which handles password authentication properly
        jump_host = bastion_port == 22 ? "#{bastion_user}@#{@options[:bastion_host]}" : "#{bastion_user}@#{@options[:bastion_host]}:#{bastion_port}"
        args += ['-J', jump_host]
        
        # Add SSH keys if specified
        if @options[:key_files]
          Array(@options[:key_files]).each do |key_file|
            args += ['-i', key_file]
          end
        end
        
        # Target connection - %h and %p will be replaced by Net::SSH
        args += ['%h', '-p', '%p']
        
        args.join(' ')
      end
      
      # Mock command execution for testing
      def mock_command_result(cmd)
        case cmd
        when /show version/
          CommandResult.new(mock_show_version_output, 0)
        when /show chassis hardware/
          CommandResult.new(mock_chassis_output, 0)
        when /show configuration/
          CommandResult.new("interfaces {\n    ge-0/0/0 {\n        unit 0;\n    }\n}", 0)
        when /show route/
          CommandResult.new("inet.0: 5 destinations, 5 routes\n0.0.0.0/0       *[Static/5] 00:00:01\n", 0)
        when /show system information/
          CommandResult.new("Hardware: SRX240H2\nOS: JUNOS 12.1X47-D15.4\n", 0)
        when /show interfaces/
          CommandResult.new("Physical interface: ge-0/0/0, Enabled, Physical link is Up\n", 0)
        else
          CommandResult.new("% Unknown command: #{cmd}", 1)
        end
      end
      
      # Mock JunOS version output for testing
      def mock_show_version_output
        <<~OUTPUT
          Hostname: lab-srx
          Model: SRX240H2
          Junos: 12.1X47-D15.4
          JUNOS Software Release [12.1X47-D15.4]
        OUTPUT
      end
      
      # Mock chassis output for testing
      def mock_chassis_output
        <<~OUTPUT
          Hardware inventory:
          Item             Version  Part number  Serial number     Description
          Chassis                                JN123456          SRX240H2
        OUTPUT
      end
      
      # JunOS error patterns from implementation plan
      JUNOS_ERROR_PATTERNS = [
        /^error:/i,
        /syntax error/i,
        /invalid command/i,
        /unknown command/i,
        /missing argument/i
      ].freeze
    end
    
    
    # Wrapper for command execution results
    class CommandResult
      attr_reader :stdout, :stderr, :exit_status
      
      def initialize(stdout, exit_status, stderr = "")
        @stdout = stdout.to_s
        @stderr = stderr.to_s
        @exit_status = exit_status.to_i
      end
    end
    
    # File abstraction for Juniper configuration and operational data
    class JuniperFile
      def initialize(connection, path)
        @connection = connection
        @path = path
      end
      
      def content
        # For Juniper devices, translate file paths to appropriate commands
        case @path
        when /\/config\/(.*)/
          # Configuration sections: /config/interfaces -> show configuration interfaces
          section = $1
          result = @connection.run_command("show configuration #{section}")
          result.stdout
        when /\/operational\/(.*)/
          # Operational data: /operational/interfaces -> show interfaces
          section = $1
          result = @connection.run_command("show #{section}")
          result.stdout
        else
          # Default to treating path as a show command
          result = @connection.run_command("show #{@path}")
          result.stdout
        end
      end
      
      def exist?
        !content.empty?
      rescue
        false
      end
    end
  end
end
