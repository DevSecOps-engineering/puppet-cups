# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'cups::server' do
  context 'with default values for all parameters' do
    let(:facts) { any_supported_os }

    it { is_expected.to contain_class('cups::server::config').that_notifies('Class[cups::server::services]') }
    it { is_expected.to contain_class('cups::server::config').that_comes_before('Class[cups::server::socket]') }

    it { is_expected.to contain_class('cups::server::services') }

    it { is_expected.to contain_class('cups::server::socket').that_comes_before('Class[cups::server::services]') }
  end
end
