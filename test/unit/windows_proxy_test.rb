# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection/windows_proxy'

describe TrainPlugins::Juniper::WindowsProxy do
  let(:dummy_class) do
    Class.new do
      include TrainPlugins::Juniper::WindowsProxy
    end
  end

  let(:instance) { dummy_class.new }

  describe '#plink_available?' do
    it 'returns false on non-Windows platforms' do
      Gem.stub :win_platform?, false do
        _(instance.plink_available?).must_equal false
      end
    end

    it 'returns false when plink.exe is not in PATH on Windows' do
      # :nocov:
      Gem.stub :win_platform?, true do
        original_path = ENV.fetch('PATH', nil)
        ENV['PATH'] = 'C:\\Windows\\System32'

        File.stub :exist?, false do
          _(instance.plink_available?).must_equal false
        end

        ENV['PATH'] = original_path
      end
      # :nocov:
    end

    it 'returns true when plink.exe is found in PATH on Windows' do
      # :nocov:
      Gem.stub :win_platform?, true do
        File.stub :exist?, ->(path) { path.end_with?('plink.exe') && path.include?('PuTTY') } do
          original_path = ENV.fetch('PATH', nil)
          ENV['PATH'] = 'C:\\Windows\\System32;C:\\PuTTY'

          _(instance.plink_available?).must_equal true

          ENV['PATH'] = original_path
        end
      end
      # :nocov:
    end
  end

  describe '#build_plink_proxy_command' do
    it 'builds basic plink command with password' do
      cmd = instance.build_plink_proxy_command('bastion.example.com', 'user', 22, 'secret123')
      _(cmd).must_include 'plink.exe'
      _(cmd).must_include '-batch'
      _(cmd).must_include '-ssh'
      _(cmd).must_include '-pw secret123'
      _(cmd).must_include 'user@bastion.example.com'
      _(cmd).must_include '-nc %h:%p'
    end

    it 'includes custom port when not 22' do
      cmd = instance.build_plink_proxy_command('bastion.example.com', 'user', 2222, 'secret123')
      _(cmd).must_include '-P 2222'
    end

    it 'omits port option for default SSH port' do
      cmd = instance.build_plink_proxy_command('bastion.example.com', 'user', 22, 'secret123')
      _(cmd).wont_include '-P 22'
    end

    it 'handles special characters in password' do
      cmd = instance.build_plink_proxy_command('bastion.example.com', 'user', 22, 'pass word!')
      _(cmd).must_include 'pass\\ word\\!'
      # Password should be properly escaped using Shellwords
    end
  end
end
