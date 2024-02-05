# Ansible

## Overview

_dbcollect_ can be run on multiple hosts in one go using Ansible. This document describe how to setup and run _dbcollect_ using Ansible Playbooks.

## Prerequisites

* Python 3 installed and configured (```python3``` should execute correctly)
* Ansible must be installed and operational on a working host (ideally, not one of the database hosts on which _dbcollect_ should be executed)
* The ansible user should have root access to the target hosts using Ansible (i.e., have password-less SSH keys configured)
* The working host has HTTP access to github.com

## Installation

* Assuming the local user is _user_

```
# Make a working directory on $HOME and make it the current dir
mkdir $HOME/multicollect && cd $HOME/multicollect

# Download the playbook, multicollect executable and example hosts file
curl -O https://raw.githubusercontent.com/outrunnl/dbcollect/devel/contrib/ansible/dbcollect.yml
curl -O https://raw.githubusercontent.com/outrunnl/dbcollect/devel/contrib/ansible/hosts
curl -O https://raw.githubusercontent.com/outrunnl/dbcollect/devel/contrib/ansible/multicollect

# Make multicollect executable
chmod 755 multicollect

# Edit the hosts file and place your hosts (full qualified domain names) in the [servers] section
vi hosts

# Test multicollect 
./multicollect -h

./multicollect -V
```

## Usage

```
# Now you can run multicollect with any options
./multicollect <options>

```