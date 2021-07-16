#!/bin/bash
# This script will setup/join the robomesh mesh network
# It requires the network interface supports the ibss network type

# Note, when running on ubuntu desktop, you must disable network manager
# on your specific device
# Do this using:
# nmcli dev set $IFACE managed no

set -e

display_usage() { 
	echo "This script must be run with super-user privileges." 
	echo "Usage: 
    $0 start <interface> <ip_addr>
        Starts a mesh network interface with the specified IP on the specified adapter

    $0 stop <interface>
        Stops the mesh on the specified network interface

    $0 start_bridge <mesh_interface> <network_interface>
        Starts a network bridge named mesh-bridge between the mesh and network interface. 
        In other words, this allows traffic between mesh_interface and network_interface. 
        Useful for connecting non-linux devices or allowing the mesh network access to the
        internet. Call this after starting the mesh using the start command.

    $0 stop_bridge
        Stops the bridge started by start_bridge
"
} 

# if less than two arguments supplied, display usage 
if [  $# -le 1 ] 
then 
    display_usage
    exit 1
fi 

# check whether user had supplied -h or --help . If yes display usage 
if [[ ( $# == "--help") ||  $# == "-h" ]] 
then 
    display_usage
    exit 0
fi 

# display usage if the script is not run as root user 
if [[ "$EUID" -ne 0 ]]; then 
    echo "This script must be run as root!" 
    exit 1
fi 

MODE=$1
IFACE=$2

MESH_ID=robomesh
FREQUENCY=2412
FREQ_BAND=HT20
MESH_MAC="00:11:22:33:44:55"
SUBNET="24"
BRIDGE_IFACE="mesh-bridge"
BATMAN_IFACE="bat0"

if [ "$MODE" = "start" ]; then
    if [  $# -le 2 ] 
    then 
        display_usage
        exit 1
    fi 
    set -x
    IP_ADDR=$3
    ## Setup adapter for ad-hoc networking
    # Converts device to ad-hoc networking
    iw dev $IFACE set type ibss
    # Add 32 bytes to packet size for batman header
    ip link set up mtu 1532 dev $IFACE
    # Create/join the network on the specified frequency and band
    iw dev $IFACE ibss join $MESH_ID $FREQUENCY $FREQ_BAND fixed-freq $MESH_MAC

    ## Setup batman adapter
    batctl if add $IFACE
    ip link set up dev $BATMAN_IFACE
    # Optional, but we want IPv4 addressing over batman
    ip addr add "${IP_ADDR}/${SUBNET}" dev $BATMAN_IFACE
elif [ "$MODE" = "stop" ]; then
    set -x
    iw dev $IFACE set type managed
    ip link set up mtu 1500 dev $IFACE
    ip link del $BATMAN_IFACE
elif [ "$MODE" = "start_bridge" ]; then
    set -x
    EXT_IFACE=$3
    ip link add name $BRIDGE_IFACE type bridge
    ip link set dev $EXT_IFACE master $BRIDGE_IFACE
    ip link set dev $BATMAN_IFACE master $BRIDGE_IFACE

    ip link set up dev $EXT_IFACE
    ip link set up dev $BATMAN_IFACE
    ip link set up dev $BRIDGE_IFACE
elif [ "$MODE" = "stop_bridge" ]; then
    set -x
    ip link del $BRIDGE_IFACE
else
    echo "Invalid mode: $MODE"
    exit 1
fi


