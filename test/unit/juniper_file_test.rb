# frozen_string_literal: true

require_relative '../helper'

describe TrainPlugins::Juniper::JuniperFile do
  let(:mock_connection) { Minitest::Mock.new }

  describe '#content' do
    it 'translates /config/ paths to show configuration commands' do
      file = TrainPlugins::Juniper::JuniperFile.new(mock_connection, '/config/interfaces')
      result = Minitest::Mock.new
      result.expect(:stdout, 'interface configuration output')

      mock_connection.expect(:run_command, result, ['show configuration interfaces'])

      _(file.content).must_equal 'interface configuration output'
      mock_connection.verify
    end

    it 'translates /operational/ paths to show commands' do
      file = TrainPlugins::Juniper::JuniperFile.new(mock_connection, '/operational/interfaces')
      result = Minitest::Mock.new
      result.expect(:stdout, 'interface status output')

      mock_connection.expect(:run_command, result, ['show interfaces'])

      _(file.content).must_equal 'interface status output'
      mock_connection.verify
    end

    it 'returns empty string for unsupported paths' do
      file = TrainPlugins::Juniper::JuniperFile.new(mock_connection, '/unsupported/path')
      result = Minitest::Mock.new
      result.expect(:stdout, '')

      mock_connection.expect(:run_command, result, ['show /unsupported/path'])

      _(file.content).must_equal ''
      mock_connection.verify
    end
  end

  describe '#exist?' do
    it 'returns true when content is not empty' do
      file = TrainPlugins::Juniper::JuniperFile.new(mock_connection, '/config/system')
      result = Minitest::Mock.new
      result.expect(:stdout, 'system configuration')

      mock_connection.expect(:run_command, result, ['show configuration system'])

      _(file.exist?).must_equal true
      mock_connection.verify
    end

    it 'returns false when content is empty' do
      file = TrainPlugins::Juniper::JuniperFile.new(mock_connection, '/config/nonexistent')
      result = Minitest::Mock.new
      result.expect(:stdout, '')

      mock_connection.expect(:run_command, result, ['show configuration nonexistent'])

      _(file.exist?).must_equal false
      mock_connection.verify
    end

    it 'returns false on error' do
      # Create a stub connection that raises an error
      error_connection = Object.new
      def error_connection.run_command(_cmd)
        raise StandardError, 'Connection error'
      end

      file = TrainPlugins::Juniper::JuniperFile.new(error_connection, '/config/system')

      _(file.exist?).must_equal false
    end
  end
end
