! FRR configuration for core router
! Simulates a Unifi Security Gateway or UDM
frr version 8.0
frr defaults traditional
hostname ${ROUTER_HOSTNAME:-core-router}
log syslog informational
no ipv6 forwarding
service integrated-vtysh-config

! Management interface
interface eth0
 description Management
 ip address ${MGMT_IP:-172.20.10.1}/${MGMT_PREFIX:-24}
!

! LAN interface - Office VLAN
interface eth1
 description LAN-Office-VLAN${OFFICE_VLAN_ID:-10}
 ip address ${OFFICE_NETWORK_GW:-10.0.0.1}/${OFFICE_PREFIX:-24}
!

! LAN interface - Guest VLAN
interface eth2
 description LAN-Guest-VLAN${GUEST_VLAN_ID:-20}
 ip address ${GUEST_NETWORK_GW:-10.0.1.1}/${GUEST_PREFIX:-24}
!

! Inter-switch trunk
interface eth3
 description Trunk-to-Dist-Switch
 ip address ${TRUNK_IP:-192.168.1.1}/${TRUNK_PREFIX:-24}
!

! DMZ interface
interface eth4
 description DMZ
 ip address ${DMZ_NETWORK_GW:-192.168.100.1}/${DMZ_PREFIX:-24}
!

! Static routes (simulating internet gateway)
ip route 0.0.0.0/0 ${DEFAULT_GW:-172.20.10.254}

! Access control lists (firewall rules)
access-list 10 permit ${OFFICE_NETWORK:-10.0.0.0}/${OFFICE_PREFIX:-24}
access-list 20 permit ${GUEST_NETWORK:-10.0.1.0}/${GUEST_PREFIX:-24}
access-list 100 deny ip ${GUEST_NETWORK:-10.0.1.0}/${GUEST_PREFIX:-24} ${OFFICE_NETWORK:-10.0.0.0}/${OFFICE_PREFIX:-24}
access-list 100 permit ip any any

! Route maps for policy-based routing
route-map OFFICE-TO-INTERNET permit 10
 match ip address 10
!

route-map GUEST-TO-INTERNET permit 10
 match ip address 20
!

! OSPF configuration (if using dynamic routing)
router ospf
 ospf router-id ${OSPF_ROUTER_ID:-192.168.1.1}
 network ${TRUNK_NETWORK:-192.168.1.0}/${TRUNK_PREFIX:-24} area 0
 network ${OFFICE_NETWORK:-10.0.0.0}/${OFFICE_PREFIX:-24} area 0
 network ${GUEST_NETWORK:-10.0.1.0}/${GUEST_PREFIX:-24} area 0
 passive-interface eth1
 passive-interface eth2
!

! BGP configuration (optional, disabled by default)
${BGP_CONFIG:-! BGP not configured}

! VTY configuration for management
line vty
 ${VTY_PASSWORD:+password ${VTY_PASSWORD}}
!

! Additional custom configurations
${CUSTOM_CONFIG:-! No custom configurations}
