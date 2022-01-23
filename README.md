# Docker Events
A simple Bash script that posts Docker Events to Telegram. It is minimal implementation and it is using a few MB of RAM and low CPU usage.

It is built for all architectures supported by `alpine` docker image.

By default it is sending container `start/stop/unhealthy` status for non zero exit codes and ignoring containers that started with the restart policy value `no`.

You can define `HOST_NAME` for each instance, or mount `/etc/hostname` as read only. That will be used in notification message title.

Also you can set up filters using environment variables to get notifications you need. Use bash patterns [wiki.bash-hackers.org/syntax/pattern](https://wiki.bash-hackers.org/syntax/pattern)

# Environment variables
`TELEGRAM_API_TOKEN` - Telegram bot API key\
`TELEGRAM_GROUP_ID` - Telegram group id

`FILTER_NAME` - filter container name (default: `+(*)`)\
`FILTER_IMAGE` - filter image name (default: `+(*)`)\
`FILTER_HEALTH` - filter health status (default: `!(healthy)`)\
`FILTER_EXITCODE` - filter exit code (default: `!(0|130)`)\
`FILTER_RESTART_POLICY` - filter restart policy (default: `!(no)`)

`HOST_NAME` - define a host name for notifications, by default it reads the `/etc/hostname` file

# Example commands
`docker run -d --name='DockerEvents' -e 'TELEGRAM_API_TOKEN'='..' -e 'TELEGRAM_GROUP_ID'='..' -v '/var/run/docker.sock':'/var/run/docker.sock':'ro' -v '/etc/hostname':'/etc/hostname':'ro' --cpus="0.1" -m 50M --restart always 'julyighor/dockerevents:latest'`

# Source code Mirrors
[gitlab.com/ighor/DockerEvents](https://gitlab.com/ighor/DockerEvents)\
[github.com/JulyIghor/DockerEvents](https://github.com/JulyIghor/DockerEvents)

# Docker registry
[hub.docker.com/r/julyighor/dockerevents](https://hub.docker.com/r/julyighor/dockerevents)\
[registry.gitlab.com/ighor/dockerevents](https://registry.gitlab.com/ighor/dockerevents)
