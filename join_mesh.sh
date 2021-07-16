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
	echo -e "\nUsage: $0 start <interface> <ip_addr>\n$0 stop <interface> \nRepurpose the specified interface for mesh networking, assigning it the specified ipv4 address" 
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
IP_ADDR=$3

MESH_ID=robomesh
FREQUENCY=2412
FREQ_BAND=HT20
MESH_MAC="00:11:22:33:44:55"
SUBNET="24"

if [ "$MODE" = "start" ]; then
    if [  $# -le 2 ] 
    then 
        display_usage
        exit 1
    fi 
    set -x
    ## Setup adapter for ad-hoc networking
    # Converts device to ad-hoc networking
    iw dev $IFACE set type ibss
    # Add 32 bytes to packet size for batman header
    ip link set up mtu 1532 dev $IFACE
    # Create/join the network on the specified frequency and band
    iw dev $IFACE ibss join $MESH_ID $FREQUENCY $FREQ_BAND fixed-freq $MESH_MAC

    ## Setup batman adapter
    batctl if add $IFACE
    ip link set up dev bat0
    # Optional, but we want IPv4 addressing over batman
    ip addr add "${IP_ADDR}/${SUBNET}" dev bat0
elif [ "$MODE" = "stop" ]; then
    set -x
    iw dev $IFACE set type managed
    ip link set up mtu 1500 dev $IFACE
    ip link del bat0
else
    echo "Invalid mode: $MODE"
    exit 1
fi


