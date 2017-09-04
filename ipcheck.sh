
#!/bin/bash

# Simple linux script that checks the external ip address, compares it to a saved version 
# or saves it in a txt file (if there's no saved version), and sends it to the provided email address.
#   note - installed outgoing mail service needed 


now=$(date)
location="/tmp/myip"
mkdir -p $location

# log file
log="$location/ip.log"

# file for storing ip address
current_address="$location/curr_address.txt"

echo "---------------------------------------------" >> ${log}
if [ ! -e "$current_address" ]; then
   echo "Text file with address does not exist - creating it. " >> ${log}
   touch "$current_address"
fi


# check ip address and update log
my_addr=$(curl icanhazip.com)
echo "Last update: $now" >> ${log}
echo "My current address is $my_addr". >> ${log}


# read old address from file; if the file is empty, use a fake address
old_addr=$(head -1 "${current_address}")
if [[ $old_addr == " " ]]; then
   old_addr="not defined"
fi
echo "Old address: $old_addr" >> ${log}


# compare addresses and perform actions
if [[ $my_addr == $old_addr ]]; then
    echo "IP addresses match - no need to update" >> ${log}
else
    echo "IP Address $my_addr needs to be updated." >> ${log}
    echo "$my_addr" > "${current_address}"
    echo "Address updated. Sending email." >> ${log}
    # need to send an email
    echo "IP Adddress has changed. New address is ${my_addr}" |mail mymail@gmail.com
    echo "Email has been sent." >> ${log}
fi
