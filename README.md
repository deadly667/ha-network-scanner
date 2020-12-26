# Fing network scanner

Of course that you can buy original Fingbox but that was not idea. 

![Telegram2](/images/Telegram2.jpg)

## Motivation

I'm not paranoid about network security, but I wanted to know if some device joins my network. Idea is that I have some tool which will scan my local network each 30 minutes and see if any new, unknown, device is present and send notification to telegram with information about that device. 

## Setup

I created very simple bash script which I'm running on my Raspberry Pi 3. It can be also optimized but well, it's working :)

### What I'm doing there?

Script runs Fing command line tool which returns CSV style table of all devices in defined network. Then for each row in that table I check if that device is present in ignoreddevices.txt file. If not then it checks knowndevices.txt file for that device and also checks if that device has still the same Ip address. This is useful if you didn't setup static Ip address, then you will get notification if some of your devices changed Ip. Also this is useful against attacks when someone fakes your known device mac address. 

Report for each device is published to MQTT. 


### Required libraries

First you have to install chkconfig tool.

`sudo apt install chkconfig`

Then you need to download Fing CLI. 

https://www.fing.com/products/development-toolkit

I downloaded `Fing CLI - Linux Debian - v5.5.2` zip and there you will find:

`fing-5.5.2-arm64.deb` which is needed for RPi 3  but there are other .deb files for all Linux distributions. 

Install .deb file via dpkg or apt command: 

`sudo apt install path_to_deb_file`

or

`sudo dpkg -i path_to_deb_file`


You need to install MQTT clients:

`sudo apt install mosquitto-clients`

and now you have all needed libraries. 

### Script

In `network_tracker.sh` script you have to put your data for: 

* `net` - network which will Fing search (mine is 192.168.0.0/24)
* `mqtt_host` - host for MQTT broker
* `mqtt_user` - MQTT user
* `mqtt_password` - MQTT password
* path to `knowndevices.txt` and `ignoreddevices.txt`


`network_tracker.sh`:

```
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
```

`knowndevices.txt`:
```
34:e4:8b:72:96:f7;192.168.0.1;Ubee
34:e4:8b:72:97:f8;192.168.0.2;Device 1
```

In knowndevices file you have to put all your devices in format `MAC_ADDR;IP_ADDR;FRENDLY_NAME`. In my example you can see that I put my Ubee router mac: 34:e4:8b:72:96:f7 which is on IP 192.168.0.1 IP address and I put Ubee as Friendly name. Each device has to be in new row.

`ignoreddevices.txt`:
```
8c:30:75:36:9b:b5
```
In ignoreddevices file you have to put mac address of all devices which you don't want to track. The above mac is just example. 


I put `network_tracker.sh` script in cronjob. It will run it each xx:01 and xx:31. You have to use root cronjob or give Fing CLI root permissions.  

```
1,31 * * * * path_to_scipt/network_tracker.sh >> path_to_logs/network_tracker.log
```


## Home Assistant automation

I created automation which checks MQTT for network alerts and sends them to Telegram:

```
- alias: Network tracker
  description: ''
  id: 24b9f12c-b1b5-4899-b7f9-6078d6c8e775
  mode: single
  trigger:
  - platform: mqtt
    topic: networkTracker/alert
  condition: []
  action:
  - service: notify.telegrambotme
    data_template:
      message: '🚨 NETWORK ALERT! 🚨 {{ trigger.payload }}'
```

![Telegram1](/images/Telegram1.jpg)
![Telegram2](/images/Telegram2.jpg)
