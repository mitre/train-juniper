#!/bin/bash
# Simple Juniper JunOS CLI simulator for testing

case "$1" in
  "version")
    cat << 'EOF'
Hostname: vsrx-test
Model: vSRX
Junos: 20.4R3.8
JUNOS Software Release [20.4R3.8] (build date: 2021-04-16 01:35:12 UTC)

Junos Space Platform: Unknown
BIOS: PC BIOS 1.12.0
Hostname: vsrx-test
Chassis type: vSRX-VirtualFirewall
Chassis S/N: 12345678
  Hardware         System Rev:    1      Chassis S/N: 12345678
  Built-in devices:
    Built-in Ethernet : 4 ports
                        Virtualized
EOF
    ;;
  "chassis")
    if [[ "$2" == "hardware" ]]; then
      echo "Chassis                                Hardware               Chassis"
      echo "Device         Version  Part number  Serial number      Description"
      echo "Chassis                                 12345678           vSRX-VirtualFirewall"
    fi
    ;;
  "interfaces")
    if [[ "$2" == "terse" ]]; then
      cat << 'EOF'
Interface               Admin Link Proto    Local                 Remote
ge-0/0/0                up    up
ge-0/0/0.0              up    up   inet     192.168.1.1/24
ge-0/0/1                up    down
lo0                     up    up
lo0.0                   up    up   inet     127.0.0.1          --> 0/0
lo0.16384               up    up   inet     127.0.0.1
EOF
    fi
    ;;
  *)
    echo "Unknown command: show $*"
    echo "% Invalid input detected at '^' marker."
    exit 1
    ;;
esac