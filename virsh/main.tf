terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
  }
}


######################################### Define networks  ###################################################################

#### Provider 1 ###

data "openstack_networking_network_v2" "provider_1" {  
  name = "clabext01"
}

data "openstack_networking_subnet_v2" "provider_1" {  
  name = "clabext01_ipv4"
}


######################################### Security group  ###################################################################

resource "openstack_networking_secgroup_v2" "secgroup" {
  name        = "test_security_group"
  description = "Security group for test"
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  #port_range_min    = 22
  #port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "tcp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "udp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "udp"
  port_range_min    = 22
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}

resource "openstack_networking_secgroup_rule_v2" "sctp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "sctp"
  port_range_min    = 22
  port_range_max    = 65535
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = "${openstack_networking_secgroup_v2.secgroup.id}"
}


######################################### Create ports  ###################################################################

# Compute:
resource "openstack_networking_port_v2" "compute_provider_1" {
  count               = "4"
  name                = "test_compute_${count.index}_provider_1"
  network_id          = "${data.openstack_networking_network_v2.provider_1.id}"
  admin_state_up      = "true"
  security_group_ids  = [ "${openstack_networking_secgroup_v2.secgroup.id}" ]


  allowed_address_pairs {
    ip_address = "0.0.0.0/0"
  }
}

######################################### Keypair  ###################################################################
resource "openstack_compute_keypair_v2" "key" {
  name          = "test_key"
  public_key    = file("~/.ssh/id_rsa.pub")
}

######################################### Instances  ###################################################################


######  Compute   #####
resource "openstack_compute_instance_v2" "compute" {
  count              = "4"
  name               = "test-compute-${count.index}"
  flavor_name        = "m1.medium"
  image_name         = "debian_11"
  key_pair           = "${openstack_compute_keypair_v2.key.name}"
  availability_zone  = "nova"
  #security_groups    = [ "test_security_group" ]

 # Provider Network 1
  network {    
    port             = "${openstack_networking_port_v2.compute_provider_1[count.index].id}"
  }


  depends_on = [
    openstack_networking_secgroup_v2.secgroup
  ]
}

