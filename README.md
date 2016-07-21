# trinityX - quick start for the impatients

Detailed documentation of the installer can be found in configuration/README.rst

- Install CentOS Minimal on your controller
- Run the following commands:
```
yum install git
git clone http://github.com/clustervision/trinityx
cd trinityX/configuration
```
- edit controller.cfg to suit your needs (most defaults are correct but you probably need to adjust the network interfaces)
- Run:
```
./configure.sh controller.cfg |& tee -a /var/log/trinity-installer.log
```

