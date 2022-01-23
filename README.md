# DockerEvents
Bash script that posts Docker Events to Telegram

# Example
docker run -d --name='DockerEvents' -e 'TELEGRAM_API_TOKEN'='..' -e 'TELEGRAM_GROUP_ID'='..' -v '/var/run/docker.sock':'/var/run/docker.sock':'ro' -v '/etc/hostname':'/etc/hostname':'ro' --cpus="0.2" -m 128M --restart always 'registry.gitlab.com/ighor/dockerevents:latest'
