# Docker Events
Bash script that posts Docker Events to Telegram. It is made to use low RAM and CPU usage.

# Environment variables
`TELEGRAM_API_TOKEN` - Telegram bot API key\
`TELEGRAM_GROUP_ID` - Telegram group id

`FILTER_NAME` - filter container name (default: `+(*)`)\
`FILTER_IMAGE` - filter image name (default: `+(*)`)\
`FILTER_HEALTH` - filter health status (default: `!(healthy)`)\
`FILTER_EXITCODE` - filter exit code (default: `!(0|130)`)\
`FILTER_RESTART_POLICY` - filter restart policy (default: `!(no)`)

`HOST_NAME` - define a host name for notifications, by default it reads the `/etc/hostname` file

# Example
`docker run -d --name='DockerEvents' -e 'TELEGRAM_API_TOKEN'='..' -e 'TELEGRAM_GROUP_ID'='..' -v '/var/run/docker.sock':'/var/run/docker.sock':'ro' -v '/etc/hostname':'/etc/hostname':'ro' --cpus="0.1" -m 50M --restart always 'julyighor/dockerevents:latest'`
