# frozen_string_literal: true

require 'shellwords'

require 'beaker'
require 'beaker-puppet'
require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'

# Beaker related configuration
# http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL
RSpec.configure do |c|
  project_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  c.before(:suite) do
    hosts.each do |host|
      run_puppet_install_helper_on(host) unless ENV['BEAKER_provision'] == 'no'
      install_module_on(host)
      scp_to(host, File.join(project_root, 'spec/fixtures/ppd/textonly.ppd'), '/tmp/')
    end
  end
end

# Custom helper functions

def ensure_cups_is_running
  apply_manifest('class { "cups": }', catch_failures: true)
end

def add_printers(*names)
  names.each do |name|
    shell("lpadmin -E -p #{Shellwords.escape(name)} -m drv:///sample.drv/generic.ppd -o printer-is-shared=false")
  end
end

def add_printers_to_classes(class_members)
  add_printers('Dummy')
  class_members.each_key do |classname|
    members = class_members[classname]
    members = %w[Dummy] if members.empty?
    members.each do |printername|
      shell("lpadmin -E -p #{Shellwords.escape(printername)} -c #{Shellwords.escape(classname)}")
    end
    shell("lpadmin -E -p #{Shellwords.escape(classname)} -o printer-is-shared=false")
  end
  remove_queues('Dummy')
end

def remove_queues(*names)
  names.flatten.each do |name|
    shell("lpadmin -E -x #{Shellwords.escape(name)}", acceptable_exit_codes: [0, 1])
  end
end

def purge_all_queues
  request = '{
    OPERATION CUPS-Get-Printers
    GROUP operation
    ATTR charset attributes-charset utf-8
    ATTR language attributes-natural-language en
    DISPLAY printer-name
  }'
  result = shell('ipptool -t ipp://localhost/ /dev/stdin', stdin: request, acceptable_exit_codes: [0, 1])
  queues = result.stdout.scan(%r{printer-name \(nameWithoutLanguage\) = ([^\s\"\'\\,#/]+)})
  remove_queues(queues)
end
