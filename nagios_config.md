# Nagios Config

## Installation des Docker Containers

Wir verwenden den Container von https://github.com/JasonRivers/Docker-Nagios

```
docker run -d --name nagios4 -v C:\Temp\nagios\etc:/opt/nagios/etc/ -v C:\Temp\nagios\custom_libexec:/opt/nagios/custom_libexec/ -p 0.0.0.0:8080:80 jasonrivers/nagios:latest
```

## Service hinzufügen

https://kifarunix.com/add-hosts-to-nagios-server-for-monitoring/

## LDAP und Certificate Check Plugin aktivieren

apt-get update && apt-get install -y libcrypt-x509-perl libtext-glob-perl
/opt/nagios/libexec/check_ssl_validity -H e-formular.spengergasse.at


/opt/nagios/libexec

https://exchange.nagios.org/directory/Plugins/Security/check_ssl_validity/details


## Eigenes Plugin schreiben

/opt/nagios/etc/resource.cfg 
$USER2$=/opt/nagios/custom_libexec


https://www.howtoforge.com/tutorial/write-a-custom-nagios-check-plugin/

## Konfiguration neu starten

In der Bash des Containers:
nagios -v /opt/nagios/etc/nagios.cfg 

Dann den Container neu starten.
