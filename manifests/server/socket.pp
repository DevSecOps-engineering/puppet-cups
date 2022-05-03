# @private
#
# @summary Avoid ipptool errors when Cups is slow to start
#
# Problem statement: on some OSes (most notably RHEL7 and derivatives), the
# Cups service may have started and not listen on the IPP port yet. This causes
# a problem when this module (re)starts the service and expects to be able to
# add/remove printers with ipptool right after.
#
# If `$cups::socket_manage` is enabled, this class modifies the standard
# `cups.socket` service to also manage the IPP port. This way, systemd will
# accept the incoming connections and hand them off to Cups once it is really
# started. This is mostly a kludge for a 3rd party bug, but still required to
# make the module behave reliably.
#
# If `$cups::socket_manage` is disabled, this workaround is removed.
#
# The `$cups::socket_ensure` argument may optionnally be set to `stopped`, and
# this setting should probably match `$cups::service_ensure`.
#
# The `$cups::service_names` argument is used to generate the socket services,
# ie. each X.service will have its X.socket managed as described above.
#
# @author Thomas Equeter
# @since 3.0.0
#
class cups::server::socket inherits cups::server {

  $_dropin_file = systemd::dropin_file { 'workaround-puppet-cups-35.conf':
    ensure  => if $cups::socket_manage { 'present' } else { 'absent' },
    unit    => 'cups.socket',
    content => @(END),
      [Socket]
      ListenStream=[::1]:631
      |END
  }

  if $cups::socket_manage {
    Array($cups::service_names, true).each |$_service_name| {
      $_safe_name = shell_escape($_service_name)

      service { "${_service_name}.socket":
        ensure    => $cups::socket_ensure,
        # Both units listen to port 631, however cups.service will play nice if
        # cups.socket is started first. See sd_listen_fds(3).
        start     => "systemctl stop ${_safe_name}.service && systemctl start ${_safe_name}.socket",
        restart   => "systemctl stop ${_safe_name}.service && systemctl restart ${_safe_name}.socket",
        subscribe => $_dropin_file,
      }
    }
  }
}

