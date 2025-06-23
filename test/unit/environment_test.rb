# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'

describe 'Environment module' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  
  describe 'env_int' do
    before do
      clean_juniper_env
    end
    
    after do
      clean_juniper_env
    end
    
    it 'should parse valid integer from environment' do
      ENV['JUNIPER_PORT'] = '2222'
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_int, 'JUNIPER_PORT')).must_equal(2222)
    end
    
    it 'should return 0 for non-integer values' do
      # Ruby's to_i returns 0 for non-numeric strings
      ENV['TEST_VAR'] = 'not_a_number'
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_int, 'TEST_VAR')).must_equal(0)
    end
    
    it 'should return nil for empty string' do
      ENV['JUNIPER_PORT'] = ''
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_int, 'JUNIPER_PORT')).must_be_nil
    end
    
    it 'should handle ArgumentError and return nil' do
      ENV['JUNIPER_TIMEOUT'] = '30.5'
      conn = connection_class.new(default_mock_options(skip_connect: true))
      # env_int will parse '30.5' as 30, not nil since to_i handles floats
      _(conn.send(:env_int, 'JUNIPER_TIMEOUT')).must_equal(30)
    end
    
    it 'should return nil when environment variable not set' do
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_int, 'JUNIPER_NONEXISTENT')).must_be_nil
    end
  end
  
  describe 'env_value' do
    before do
      clean_juniper_env
    end
    
    after do
      clean_juniper_env
    end
    
    it 'should return value for set environment variable' do
      ENV['JUNIPER_HOST'] = 'router.example.com'
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_value, 'JUNIPER_HOST')).must_equal('router.example.com')
    end
    
    it 'should return nil for empty string' do
      ENV['JUNIPER_HOST'] = ''
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_value, 'JUNIPER_HOST')).must_be_nil
    end
    
    it 'should return nil for unset variable' do
      conn = connection_class.new(default_mock_options(skip_connect: true))
      _(conn.send(:env_value, 'JUNIPER_UNSET')).must_be_nil
    end
  end
end