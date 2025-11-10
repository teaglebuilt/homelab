# Containerlab topology template for simulating network infrastructure
# This topology creates a test environment that mimics a typical Unifi deployment
name: ${LAB_NAME:-unifi-test-lab}

topology:
  kinds:
    linux:
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot:latest}

  nodes:
    # Core router - simulates USG/UDM
    core-router:
      kind: linux
      image: ${FRR_IMAGE:-frrouting/frr:latest}
      ports:
        - "${FRR_VTYSH_PORT:-2601}:2601"  # FRR vtysh
      binds:
        - ./configs/frr/core-router:/etc/frr
      exec:
        - ip addr add ${TRUNK_IP:-192.168.1.1}/${TRUNK_PREFIX:-24} dev eth1
        - ip addr add ${OFFICE_NETWORK_GW:-10.0.0.1}/${OFFICE_PREFIX:-24} dev eth2
        - ip addr add ${GUEST_NETWORK_GW:-10.0.1.1}/${GUEST_PREFIX:-24} dev eth3
      labels:
        role: core-router
        network: management

    # Distribution switches - simulates Unifi switches
    dist-switch-1:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${DIST_SWITCH1_IP:-192.168.1.10}/${TRUNK_PREFIX:-24} dev eth1
        - ip link add name br0 type bridge
        - ip link set br0 up
        - ip link set eth1 master br0
        - ip link set eth2 master br0
        - ip link set eth3 master br0
      labels:
        role: distribution-switch
        location: rack-1

    dist-switch-2:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${DIST_SWITCH2_IP:-192.168.1.11}/${TRUNK_PREFIX:-24} dev eth1
        - ip link add name br0 type bridge
        - ip link set br0 up
        - ip link set eth1 master br0
        - ip link set eth2 master br0
        - ip link set eth3 master br0
      labels:
        role: distribution-switch
        location: rack-2

    # Access switches - simulates edge switches
    access-switch-1:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${ACCESS_SWITCH1_IP:-192.168.1.20}/${TRUNK_PREFIX:-24} dev eth1
        - ip link add name br0 type bridge
        - ip link set br0 up
        - ip link set eth1 master br0
        - ip link set eth2 master br0
      labels:
        role: access-switch
        location: floor-1

    access-switch-2:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${ACCESS_SWITCH2_IP:-192.168.1.21}/${TRUNK_PREFIX:-24} dev eth1
        - ip link add name br0 type bridge
        - ip link set br0 up
        - ip link set eth1 master br0
        - ip link set eth2 master br0
      labels:
        role: access-switch
        location: floor-2

    # VLAN test endpoints
    vlan10-client:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${OFFICE_CLIENT_IP:-10.0.0.100}/${OFFICE_PREFIX:-24} dev eth1
        - ip route add default via ${OFFICE_NETWORK_GW:-10.0.0.1}
      labels:
        vlan: "${OFFICE_VLAN_ID:-10}"
        network: office

    vlan20-client:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${GUEST_CLIENT_IP:-10.0.1.100}/${GUEST_PREFIX:-24} dev eth1
        - ip route add default via ${GUEST_NETWORK_GW:-10.0.1.1}
      labels:
        vlan: "${GUEST_VLAN_ID:-20}"
        network: guest

    # DMZ client
    dmz-client:
      kind: linux
      image: ${NETSHOOT_IMAGE:-nicolaka/netshoot}
      exec:
        - ip addr add ${DMZ_CLIENT_IP:-192.168.100.100}/${DMZ_PREFIX:-24} dev eth1
      labels:
        network: dmz

    # Test servers
    test-server-1:
      kind: linux
      image: ${NGINX_IMAGE:-nginx:alpine}
      exec:
        - ip addr add ${TEST_SERVER1_IP:-10.0.0.50}/${OFFICE_PREFIX:-24} dev eth1
      ports:
        - "${TEST_SERVER1_PORT:-8081}:80"
      labels:
        role: test-server
        vlan: "${OFFICE_VLAN_ID:-10}"

    test-server-2:
      kind: linux
      image: ${NGINX_IMAGE:-nginx:alpine}
      exec:
        - ip addr add ${TEST_SERVER2_IP:-10.0.1.50}/${GUEST_PREFIX:-24} dev eth1
      ports:
        - "${TEST_SERVER2_PORT:-8082}:80"
      labels:
        role: test-server
        vlan: "${GUEST_VLAN_ID:-20}"

  links:
    # Core router connections
    - endpoints: ["core-router:eth1", "dist-switch-1:eth1"]
      mtu: ${MTU_SIZE:-9000}
    - endpoints: ["core-router:eth2", "dist-switch-2:eth1"]
      mtu: ${MTU_SIZE:-9000}

    # Distribution to access layer
    - endpoints: ["dist-switch-1:eth2", "access-switch-1:eth1"]
    - endpoints: ["dist-switch-2:eth2", "access-switch-2:eth1"]

    # Cross-connect for redundancy
    - endpoints: ["dist-switch-1:eth3", "dist-switch-2:eth3"]

    # Client connections
    - endpoints: ["access-switch-1:eth2", "vlan10-client:eth1"]
    - endpoints: ["access-switch-2:eth2", "vlan20-client:eth1"]

    # Server connections
    - endpoints: ["dist-switch-1:eth4", "test-server-1:eth1"]
    - endpoints: ["dist-switch-2:eth4", "test-server-2:eth1"]

    # DMZ connection
    - endpoints: ["core-router:eth4", "dmz-client:eth1"]

# Management network configuration
mgmt:
  network: ${MGMT_NETWORK_NAME:-unifi-mgmt}
  ipv4-subnet: ${MGMT_SUBNET:-172.20.10.0/24}
