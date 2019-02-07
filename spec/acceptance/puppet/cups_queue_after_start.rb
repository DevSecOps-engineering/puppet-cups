# frozen_string_literal: true

require 'spec_helper_acceptance'

RSpec.describe 'Custom type `cups_queue`' do
  describe 'when the Cups service is starting' do
    before(:each) do
      ensure_cups_is_running
      # Cups takes time to listen to IPP after service start, depending on the
      # amount of printers defined. Just a few printers are enough to cause the
      # cups_queue ipptool calls to fail right after a restart, but adding 50
      # here makes it future-proof for the ever-faster testing environments.
      printer_names = (1..50).map { |n| "Office#{n}" }
      printer_names.each do |name|
        shell("lpadmin -E -p #{name} -m drv:///sample.drv/generic.ppd -o printer-is-shared=false", silent: true)
      end
      remove_queues('Office')

      # Cleanup
      if fact('systemd') then
        shell('rm -f /etc/systemd/system/cups.socket.d/workaround-puppet-cups-35.conf')
        shell('systemctl daemon-reload', accept_all_exit_codes: true)
        shell('systemctl stop cups.socket cups.service', accept_all_exit_codes: true)
      else
        # Not needed, but for coherence with the systemd version
        shell('service cups stop')
      end
    end

    manifest = <<-MANIFEST
      class { 'cups':
        service_ensure => 'running',
      }
      cups_queue { 'Office':
        ensure => 'printer',
      }
    MANIFEST

    it 'can refresh the service and create a queue' do
      # Do NOT use ensure_cups_is_running here, it calls the cups class and
      # installs the dropin file, which is exactly what we want to test below.
      shell('service cups start')
      # Cause a rewrite of the configuration and trigger a service refresh.
      shell('rm /etc/cups/cupsd.conf')
      apply_manifest(manifest, expect_changes: true)
    end

    it 'can start the service and create a queue' do
      apply_manifest(manifest, expect_changes: true)
    end
  end
end
