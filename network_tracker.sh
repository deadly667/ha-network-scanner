#!/bin/bash
net=192.168.0.0/24
mqtt_host=__your_mqtt_host__
mqtt_topic=networkTracker/alert
mqtt_user=__your_mqtt_username__
mqtt_password=__your_mqtt_password__
known=__path_to_knowndevices.txt__
ignore=__path_to_ignoreddevices.txt__

dt=`date '+%FT%T'`
IFS="
"

for l in `fing -n $net -r 1 -o table,csv --silent`
do
        IFS=";"
        array=($l)
        fing_mac=${array[5]}
        fing_ip=${array[0]}
        fing_name=${array[6]}

        if [ `cat $ignore | grep $fing_mac | wc -l` -eq "1" ]
        then
                echo "$dt - $fing_mac is ignored!"
                continue
        fi

        if [ `cat $known | grep $fing_mac | wc -l` -eq "0" ]
        then
                echo "$dt - $fing_mac is not known!"
                mosquitto_pub -h $mqtt_host -u $mqtt_user -P $mqtt_password -t $mqtt_topic -m "New Mac: $fing_mac IP: $fing_ip FingName: $fing_name"
        elif [ `cat $known | grep $fing_mac | wc -l` -gt "1" ]
        then
                echo "$dt - $fing_mac has multiple records in knowndevices.txt"
                mosquitto_pub -h $mqtt_host -u $mqtt_user -P $mqtt_password -t $mqtt_topic -m "Multiple records in knowndevices.txt for Mac: $fing_mac IP: $fing_ip FingName: $fing_name"
        elif [ `cat $known | grep $fing_mac | wc -l` -eq "1" ]
        then
                knowndevice=($(cat $known | grep $fing_mac))
                if [ "${knowndevice[1]}" != "$fing_ip" ]
                then
                        echo "$dt - $fing_mac changed IP address from IP_OLD: ${knowndevice[1]} to IP_NEW: $fing_ip"
                        mosquitto_pub -h $mqtt_host -u $mqtt_user -P $mqtt_password -t $mqtt_topic -m "Mac: $fing_mac changed IP address from IP-OLD: ${knowndevice[1]} to IP-NEW: $fing_ip FingName: $fing_name DeviceName: ${knowndevice[2]}"
                fi
        fi

        IFS="
        "
done