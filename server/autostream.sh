#!/bin/bash

# check if env vars are set
if [ -z "$username" ]; then
        echo "username is not set"
        exit 1
fi
if [ -z "$password" ]; then
        echo "password is not set"
        exit 1
fi

uuid="47ec2a55-b6cc-4ec4-bb42-ff669d146955"
#server="https://restreamer-raspberry.vps.zaretti.be"
server="https://restreamer.vps.zaretti.be"
duration=180


current_status="stopped"
last_alive=$(date +%s)


start() {
        echo "starting..."

        docker stop obs-gui
        docker run -d --rm \
                --name=obs-cli \
                -v /opt/obs/.config/obs-studio:/root/.config/obs-studio \
                --shm-size="1gb" \
                --net=backend \
                --privileged \
                --device /dev/dri:/dev/dri \
                obs-cli

}
stop() {
        echo "stopping..."

        docker stop obs-cli
        docker run -d --rm \
                --name=obs-gui \
                -v /opt/obs:/config \
                --shm-size="1gb" \
                --net=backend \
                --privileged \
                --device /dev/dri:/dev/dri \
                obs-gui

}

check() {
        token=$(curl -s -X 'POST' $server'/api/login' -H 'accept: application/json' -H 'Content-Type: application/json' -d '{
                "username": "'$username'",
                "password": "'$password'"
        }' | jq -r .access_token)

        curl -s -X 'GET' $server'/api/v3/rtmp' -H 'accept: application/json' -H 'Authorization: Bearer '$token'' | jq 'map(.name | contains("'$uuid'")) | any'
}
docker stop obs-cli obs-gui
stop

while [ true ]; do
        exist=$(check)

        if [ "$exist" = "true" ]; then
                last_alive=$(date +%s)
        fi

        if [ "$exist" = "true" ] && [ "$current_status" = "stopped" ]; then
                start
                current_status="started"
        elif [ "$exist" = "false" ] && [ "$current_status" = "started" ]; then
                now=$(date +%s)
                stopped_duration=$(( now - last_alive ))

                if [ $stopped_duration -ge $duration ]; then
                        stop
                        current_status="stopped"
                else
                        echo "stream is dead, attempt to reconnect... $stopped_duration / $duration"
                fi
        fi

        sleep 1
done
