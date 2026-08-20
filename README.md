```
              .__                                   
  ______ _____|  |__           ________  _  ______  
 /  ___//  ___/  |  \   ______ \____ \ \/ \/ /    \ 
 \___ \ \___ \|   Y  \ /_____/ |  |_> >     /   |  \
/____  >____  >___|  /         |   __/ \/\_/|___|  /
     \/     \/     \/          |__|              \/   v 0.1.0
                                    prod by I3r1h0n
```

## description
A tool to enum linux hosts over ssh. The killer thing of this tool is an ability to run extra_checks, and easily, quickly, write your own. Check the `/extra_checks` dir for samples. 

## deps
Currently it's "paramiko", "yaml", and python 3+. Wonder how this tool works? Read the source! The only source file in `ssh_pwn.py`, and it's simple asf.

## usage
Here's the help output for ya:
```
usage: ssh_pwn.py [-h] [-u USER] [-p PASS] [-i KEY] (-t TARGET | -tL FILE) [-o FILE] [--extra-checks PATHS] [--timeout SEC]
                  [-v LEVEL]

A tool to enum linux hosts over ssh

options:
  -h, --help            show this help message and exit
  -u USER               SSH username (default: current OS user)
  -p PASS               SSH password
  -i KEY                Path to SSH private key
  -t TARGET             Single target (host or host:port)
  -tL FILE              File with targets, one per line
  -o FILE               Write JSON results to this file
  --extra-checks PATHS  Comma-separated YAML files and/or directories with extra checks
  --timeout SEC         Timeout in seconds for remote commands (default: 40)
  -v, --verbose LEVEL   Verbose level: 0=quiet, 1=default, 2=debug

target formats (for -t and lines in -tL file):
  host              192.168.1.1
  host:port         192.168.1.1:2222
  user@host         admin@192.168.1.1
  user:pass@host    admin:secret@192.168.1.1:2222
```

## creds

prod by _I3r1h0n_.
