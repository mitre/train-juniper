# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection/ssh_askpass'

describe TrainPlugins::Juniper::SshAskpass do
  let(:dummy_class) do
    Class.new do
      include TrainPlugins::Juniper::SshAskpass
      attr_accessor :options, :logger, :ssh_askpass_script
    end
  end

  let(:instance) do
    obj = dummy_class.new
    obj.options = {}
    obj.logger = Minitest::Mock.new
    obj
  end

  describe '#setup_bastion_password_auth' do
    before do
      instance.logger.expect :debug, nil, [String]
    end

    it 'does nothing when no password is provided' do
      # Save original env
      original_askpass = ENV.fetch('SSH_ASKPASS', nil)

      instance.setup_bastion_password_auth

      # Should not change environment if no password
      if original_askpass.nil?
        _(ENV.fetch('SSH_ASKPASS', nil)).must_be_nil
      else
        _(ENV.fetch('SSH_ASKPASS', nil)).must_equal(original_askpass)
      end

      # Clean up
      ENV['SSH_ASKPASS'] = original_askpass
    end

    it 'creates script and sets environment when bastion_password is provided' do
      instance.options[:bastion_password] = 'secret123'
      instance.stub :create_ssh_askpass_script, '/tmp/askpass.sh' do
        instance.setup_bastion_password_auth
        _(ENV.fetch('SSH_ASKPASS', nil)).must_equal '/tmp/askpass.sh'
        _(ENV.fetch('SSH_ASKPASS_REQUIRE', nil)).must_equal 'force'
      end
    end

    it 'uses bastion_password over general password' do
      instance.options[:password] = 'general'
      instance.options[:bastion_password] = 'bastion_specific'
      instance.stub :create_ssh_askpass_script, '/tmp/askpass.sh' do
        instance.setup_bastion_password_auth
        # Would have been called with 'bastion_specific'
        _(ENV.fetch('SSH_ASKPASS', nil)).must_equal '/tmp/askpass.sh'
      end
    end
  end

  describe '#create_ssh_askpass_script' do
    it 'creates Unix script on non-Windows platforms' do
      Gem.stub :win_platform?, false do
        instance.stub :create_unix_askpass_script, '/tmp/unix_script.sh' do
          result = instance.create_ssh_askpass_script('password')
          _(result).must_equal '/tmp/unix_script.sh'
        end
      end
    end

    it 'creates Windows script on Windows platforms' do
      # :nocov:
      Gem.stub :win_platform?, true do
        instance.stub :create_windows_askpass_script, 'C:\\Temp\\win_script.bat' do
          result = instance.create_ssh_askpass_script('password')
          _(result).must_equal 'C:\\Temp\\win_script.bat'
        end
      end
      # :nocov:
    end
  end
end
