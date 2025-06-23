# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'

describe 'BastionProxy module' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }
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
      _(ENV.fetch('SSH_ASKPASS', nil)).must_match(%r{/ssh_askpass.*\.sh$})
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')
    end

    it 'should configure bastion proxy with default port' do
      connection.instance_variable_get(:@options)[:bastion_port] = 22
      ssh_options = {}

      # Use real logger to avoid mock expectation issues
      connection.send(:configure_bastion_proxy, ssh_options)

      _(ssh_options[:proxy]).must_be_instance_of(Net::SSH::Proxy::Jump)
      _(ENV.fetch('SSH_ASKPASS', nil)).must_match(%r{/ssh_askpass.*\.sh$})
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
      _(ENV.fetch('SSH_ASKPASS', nil)).must_match(%r{/ssh_askpass.*\.sh$})
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')
    end
  end

  describe 'setup_bastion_password_auth' do
    it 'should set up SSH_ASKPASS when bastion password provided' do
      # Save original env
      original_askpass = ENV.fetch('SSH_ASKPASS', nil)
      original_require = ENV.fetch('SSH_ASKPASS_REQUIRE', nil)

      connection.send(:setup_bastion_password_auth)

      _(ENV.fetch('SSH_ASKPASS', nil)).must_match(%r{/ssh_askpass.*\.sh$})
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

      _(ENV.fetch('SSH_ASKPASS', nil)).must_match(%r{/ssh_askpass.*\.sh$})
      _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal('force')

      # Verify script contains device password
      script_content = File.read(ENV.fetch('SSH_ASKPASS', nil))
      _(script_content).must_include('secret') # device password

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
      _(File.executable?(script_path)).must_equal(true)

      content = File.read(script_path)
      _(content).must_include('#!/bin/bash')
      _(content).must_include("echo 'test_pass'")

      # Clean up
      FileUtils.rm_f(script_path)
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
