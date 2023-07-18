# Neutron configuration:
ovn-nbctl show
ovn-sbctl show
ovn-nbctl del-connection
ovn-sbctl del-connection
ovs-vsctl remove open . external-ids ovn-remote
ovs-vsctl remove open . external-ids ovn-encap-type
ovs-vsctl remove open . external-ids ovn-encap-ip


# Clear ovs configuration:
ovs-vsctl del-port br-eth1 eth1
ovs-vsctl del-br br-eth1
ovs-vsctl del-port br-eth2 eth2
ovs-vsctl del-br br-eth2
ovs-vsctl remove open . external-ids ovn-bridge-mappings
ovs-vsctl show
ovs-vsctl get open . external-ids:ovn-bridge-mappings

ovn-nbctl set-connection ptcp:6641:172.250.0.10 -- set connection . inactivity_probe=60000 
ovn-sbctl set-connection ptcp:6642:172.250.0.10 -- set connection . inactivity_probe=60000 
ovs-vsctl set open . external-ids:ovn-remote=tcp:172.250.0.10:6642 
ovs-vsctl set open . external-ids:ovn-encap-type=geneve,vxlan
ovs-vsctl set open . external-ids:ovn-encap-ip=172.250.0.10




# Create ovs configuration:
ovs-vsctl add-br br-eth1 
ovs-vsctl add-port br-eth1 eth1 
ovs-vsctl set open . external-ids:ovn-bridge-mappings=clabext01:br-eth1
ovs-vsctl show
#ovs-vsctl get open . external-ids:ovn-bridge-mappings

ovs-vsctl add-br br-eth2
ovs-vsctl add-port br-eth2 eth2 
ovs-vsctl set open . external-ids:ovn-bridge-mappings=clabext01:br-eth1,clabext02:br-eth2
ovs-vsctl show
ovs-vsctl get open . external-ids:ovn-bridge-mappings



