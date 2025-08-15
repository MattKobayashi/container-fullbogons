#!/bin/sh

su bird -s /bin/uv run fullbogons.py

cleanup() {
    echo "Shutting down BIRD..."
    birdc down & wait
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

/usr/local/bin/supercronic /bird/crontab/fullbogons-cron &
bird -u bird -c bird.conf -d & wait $!
