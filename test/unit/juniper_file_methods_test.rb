# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/connection'

describe 'JuniperFile additional methods' do
  let(:connection_class) { TrainPlugins::Juniper::Connection }
  let(:connection) { connection_class.new(default_mock_options) }
  
  describe 'to_s method' do
    it 'should return the file path' do
      file = connection.file('/config/interfaces')
      _(file.to_s).must_equal('/config/interfaces')
    end
    
    it 'should return operational paths correctly' do
      file = connection.file('/operational/system')
      _(file.to_s).must_equal('/operational/system')
    end
    
    it 'should return generic paths correctly' do
      file = connection.file('version')
      _(file.to_s).must_equal('version')
    end
  end
  
  describe 'upload method' do
    it 'should raise NotImplementedError with correct message' do
      file = connection.file('/config/test')
      
      err = _(-> { file.upload('some configuration') }).must_raise(NotImplementedError)
      _(err.message).must_equal('File operations not supported for Juniper devices - use command-based configuration')
    end
    
    it 'should raise error regardless of content' do
      file = connection.file('/tmp/test.conf')
      
      err = _(-> { file.upload('') }).must_raise(NotImplementedError)
      _(err.message).must_include('use command-based configuration')
    end
  end
  
  describe 'download method' do
    it 'should raise NotImplementedError with correct message' do
      file = connection.file('/config/running')
      
      err = _(-> { file.download('/tmp/backup.conf') }).must_raise(NotImplementedError)
      _(err.message).must_equal('File operations not supported for Juniper devices - use run_command() to retrieve data')
    end
    
    it 'should raise error regardless of local path' do
      file = connection.file('/var/log/messages')
      
      err = _(-> { file.download(nil) }).must_raise(NotImplementedError)
      _(err.message).must_include('use run_command() to retrieve data')
    end
  end
  
  describe 'inspect method' do
    it 'should include class name and path' do
      file = connection.file('/config/security')
      inspect_output = file.inspect
      
      _(inspect_output).must_include('JuniperFile')
      _(inspect_output).must_include('/config/security')
      _(inspect_output).must_match(/#<TrainPlugins::Juniper::JuniperFile/)
    end
  end
end