# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'
require 'net/ssh/proxy/command'

describe 'BastionProxy module' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }

  # Helper to assert SSH_ASKPASS script path based on platform
  def assert_ssh_askpass_script_created
    askpass_path = ENV.fetch('SSH_ASKPASS', nil)
    if Gem.win_platform?
      _(askpass_path).must_match(/ssh_askpass.*\.bat$/)
    else
      _(askpass_path).must_match(%r{/ssh_askpass.*\.sh$})
    end
  end

  let(:bastion_options) do
    default_mock_options(
      host: 'device.local',
      user: 'admin',
      password: 'secret',
      bastion_host: 'jump.example.com',
      bastion_user: 'jumpuser',
      bastion_port: 2222,
      bastion_password: 'jump_secret',
      skip_connect: true
    )
  end
  let(:connection) { connection_class.new(bastion_options) }

  describe 'configure_bastion_proxy' do
    it 'should configure bastion proxy with custom port' do
      ssh_options = {}

      # Use real logger to avoid mock expectation issues
      connection.send(:configure_bastion_proxy, ssh_options)

      _(ssh_options[:proxy]).must_be_instance_of(Net::SSH::Proxy::Jump)
      assert_ssh_askpass_script_created
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')
    end

    it 'should use plink.exe on Windows when available and password provided' do
      # :nocov:
      skip 'Non-Windows test environment' unless Gem.win_platform?

      # Save and clear SSH_ASKPASS to ensure clean test
      original_ssh_askpass = ENV.delete('SSH_ASKPASS')

      begin
        # Mock plink availability
        connection.stub :plink_available?, true do
          ssh_options = {}

          connection.send(:configure_bastion_proxy, ssh_options)

          _(ssh_options[:proxy]).must_be_instance_of(Net::SSH::Proxy::Command)
          # SSH_ASKPASS should not be set when using plink
          _(ENV.fetch('SSH_ASKPASS', nil)).must_be_nil
        end
      ensure
        # Restore original value if it existed
        ENV['SSH_ASKPASS'] = original_ssh_askpass if original_ssh_askpass
      end
      # :nocov:
    end

    it 'should fall back to standard proxy on Windows when plink not available' do
      # :nocov:
      Gem.stub :win_platform?, true do
        connection.stub :plink_available?, false do
          ssh_options = {}

          connection.send(:configure_bastion_proxy, ssh_options)

          _(ssh_options[:proxy]).must_be_instance_of(Net::SSH::Proxy::Jump)
          assert_ssh_askpass_script_created
          _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')
        end
      end
      # :nocov:
    end

    it 'should configure bastion proxy with default port' do
      connection.instance_variable_get(:@options)[:bastion_port] = 22
      ssh_options = {}

      # Use real logger to avoid mock expectation issues
      connection.send(:configure_bastion_proxy, ssh_options)

      _(ssh_options[:proxy]).must_be_instance_of(Net::SSH::Proxy::Jump)
      assert_ssh_askpass_script_created
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')
    end

    it 'should use device user if bastion_user not specified' do
      options = bastion_options.dup
      options.delete(:bastion_user)
      conn = connection_class.new(options)

      ssh_options = {}

      # Use real logger to avoid mock expectation issues
      conn.send(:configure_bastion_proxy, ssh_options)

      _(ssh_options[:proxy]).must_be_instance_of(Net::SSH::Proxy::Jump)
      assert_ssh_askpass_script_created
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')
    end
  end

  describe 'setup_bastion_password_auth' do
    it 'should set up SSH_ASKPASS when bastion password provided' do
      # Save original env
      original_askpass = ENV.fetch('SSH_ASKPASS', nil)
      original_require = ENV.fetch('SSH_ASKPASS_REQUIRE', nil)

      connection.send(:setup_bastion_password_auth)

      assert_ssh_askpass_script_created
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')

      # Clean up
      ENV['SSH_ASKPASS'] = original_askpass
      ENV['SSH_ASKPASS_REQUIRE'] = original_require
    end

    it 'should use device password if bastion password not provided' do
      options = bastion_options.dup
      options.delete(:bastion_password)
      conn = connection_class.new(options)

      # Save original env
      original_askpass = ENV.fetch('SSH_ASKPASS', nil)
      original_require = ENV.fetch('SSH_ASKPASS_REQUIRE', nil)

      conn.send(:setup_bastion_password_auth)

      assert_ssh_askpass_script_created
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')

      # Verify script contains device password
      if Gem.win_platform?
        # On Windows, SSH_ASKPASS points to wrapper batch file
        # Need to extract PowerShell script path from wrapper
        wrapper_content = File.read(ENV.fetch('SSH_ASKPASS', nil))
        ps1_path = wrapper_content.match(/-File "([^"]+)"/)[1]
        ps_content = File.read(ps1_path)
        _(ps_content).must_include('secret') # device password
      else
        script_content = File.read(ENV.fetch('SSH_ASKPASS', nil))
        _(script_content).must_include('secret') # device password
      end

      # Clean up
      ENV['SSH_ASKPASS'] = original_askpass
      ENV['SSH_ASKPASS_REQUIRE'] = original_require
    end

    it 'should not set up SSH_ASKPASS when no password available' do
      options = bastion_options.dup
      options.delete(:bastion_password)
      options.delete(:password)
      conn = connection_class.new(options)

      # Save original env
      original_askpass = ENV.fetch('SSH_ASKPASS', nil)
      original_require = ENV.fetch('SSH_ASKPASS_REQUIRE', nil)

      conn.send(:setup_bastion_password_auth)

      # Should not change environment
      if original_askpass.nil?
        _(ENV.fetch('SSH_ASKPASS', nil)).must_be_nil
      else
        _(ENV.fetch('SSH_ASKPASS', nil)).must_equal(original_askpass)
      end

      if original_require.nil?
        _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_be_nil
      else
        _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal(original_require)
      end
    end
  end

  describe 'create_ssh_askpass_script' do
    it 'should create executable script with password' do
      script_path = connection.send(:create_ssh_askpass_script, 'test_pass')

      _(File.exist?(script_path)).must_equal(true)

      if Gem.win_platform?
        _(script_path).must_match(/\.bat$/)
        content = File.read(script_path)
        _(content).must_include('@echo off')
        _(content).must_include('powershell.exe -ExecutionPolicy Bypass')
        _(content).must_match(/\.ps1/)

        # Also verify the PowerShell script contains the password
        ps1_path = content.match(/-File "([^"]+)"/)[1]
        ps_content = File.read(ps1_path)
        _(ps_content).must_include("Write-Output 'test_pass'")
      else
        _(File.executable?(script_path)).must_equal(true)
        content = File.read(script_path)
        _(content).must_include('#!/bin/bash')
        _(content).must_include("echo 'test_pass'")
      end

      # Clean up
      if Gem.win_platform? && defined?(ps1_path)
        FileUtils.rm_f(ps1_path)
      end
      FileUtils.rm_f(script_path)
    end

    it 'should escape single quotes on Windows PowerShell' do
      skip 'Windows-specific test' unless Gem.win_platform?

      wrapper_path = connection.send(:create_ssh_askpass_script, "test'pass'word")

      # The wrapper should exist
      _(File.exist?(wrapper_path)).must_equal(true)

      # Read wrapper to find PowerShell script path
      wrapper_content = File.read(wrapper_path)
      ps1_path = wrapper_content.match(/-File "([^"]+)"/)[1]

      # Check PowerShell script has escaped quotes
      ps_content = File.read(ps1_path)
      _(ps_content).must_include("test''pass''word")

      # Clean up
      FileUtils.rm_f(wrapper_path)
      FileUtils.rm_f(ps1_path)
    end
  end

  describe 'generate_bastion_proxy_command' do
    it 'should generate proxy command with custom port' do
      cmd = connection.send(:generate_bastion_proxy_command, 'jumpuser', 2222)

      _(cmd).must_include('ssh')
      _(cmd).must_include('-J jumpuser@jump.example.com:2222')
      _(cmd).must_include('-o UserKnownHostsFile=/dev/null')
      _(cmd).must_include('-o StrictHostKeyChecking=no')
      _(cmd).must_include('%h -p %p')
    end

    it 'should generate proxy command with default port' do
      cmd = connection.send(:generate_bastion_proxy_command, 'jumpuser', 22)

      _(cmd).must_include('ssh')
      _(cmd).must_include('-J jumpuser@jump.example.com')
      _(cmd).wont_include(':22') # Default port omitted
      _(cmd).must_include('%h -p %p')
    end

    it 'should include key files when specified' do
      options = bastion_options.merge(key_files: ['/path/to/key1', '/path/to/key2'])
      conn = connection_class.new(options)

      cmd = conn.send(:generate_bastion_proxy_command, 'jumpuser', 22)

      _(cmd).must_include('-i /path/to/key1')
      _(cmd).must_include('-i /path/to/key2')
    end
  end
end
