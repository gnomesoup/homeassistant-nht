# Home Assistant Configuration #

My [Home Assistant](https://www.home-assistant.io/) ([Hass.io](https://www.home-assistant.io/hassio/)) configuration.

## Command to check updates ##

``` bash
docker pull homeassistant/amd64-homeassistant:latest
docker run -it --rm -v /homeassistant:/config -e "TZ=America/Chicago" homeassistant/amd64-homeassistant hass -c /config --script check_config
```
