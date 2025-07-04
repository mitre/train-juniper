# frozen_string_literal: true

require_relative '../helper'
require 'train-juniper/helpers/mock_responses'

describe TrainPlugins::Juniper::MockResponses do
  describe '.response_for' do
    it 'returns mock chassis XML output for show chassis hardware | display xml' do
      response, exit_status = TrainPlugins::Juniper::MockResponses.response_for('show chassis hardware | display xml')

      _(exit_status).must_equal 0
      _(response).must_include '<rpc-reply'
      _(response).must_include '<chassis-inventory'
      _(response).must_include '<serial-number>JN123456</serial-number>'
    end

    it 'returns mock version XML output for show version | display xml' do
      response, exit_status = TrainPlugins::Juniper::MockResponses.response_for('show version | display xml')

      _(exit_status).must_equal 0
      _(response).must_include '<rpc-reply'
      _(response).must_include '<software-information>'
      _(response).must_include '<junos-version>12.1X47-D15.4</junos-version>'
    end

    it 'returns text output for show chassis hardware without display xml' do
      response, exit_status = TrainPlugins::Juniper::MockResponses.response_for('show chassis hardware')

      _(exit_status).must_equal 0
      _(response).must_include 'Hardware inventory:'
      _(response).must_include 'JN123456'
    end

    it 'returns text output for show version without display xml' do
      response, exit_status = TrainPlugins::Juniper::MockResponses.response_for('show version')

      _(exit_status).must_equal 0
      _(response).must_include 'Hostname: lab-srx'
      _(response).must_include 'Junos: 12.1X47-D15.4'
    end

    it 'returns error for unknown commands' do
      response, exit_status = TrainPlugins::Juniper::MockResponses.response_for('unknown command')

      _(exit_status).must_equal 1
      _(response).must_include '% Unknown command:'
    end
  end

  describe '.mock_chassis_xml_output' do
    it 'returns valid XML for chassis hardware' do
      output = TrainPlugins::Juniper::MockResponses.mock_chassis_xml_output

      _(output).must_include '<rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">'
      _(output).must_include '<chassis-inventory xmlns="http://xml.juniper.net/junos/12.1X47/junos-chassis">'
      _(output).must_include '<serial-number>JN123456</serial-number>'
      _(output).must_include '<description>SRX240H2</description>'
    end
  end

  describe '.mock_version_xml_output' do
    it 'returns valid XML for version information' do
      output = TrainPlugins::Juniper::MockResponses.mock_version_xml_output

      _(output).must_include '<rpc-reply xmlns:junos="http://xml.juniper.net/junos/12.1X47/junos">'
      _(output).must_include '<software-information>'
      _(output).must_include '<product-model>SRX240H2</product-model>'
      _(output).must_include '<junos-version>12.1X47-D15.4</junos-version>'
    end
  end
end
