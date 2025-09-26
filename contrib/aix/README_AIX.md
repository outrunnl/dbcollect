** AIX Setup **

On IBM AIX, you need to install Python first. You can get python for AIX from
[AIX Toolbox (IBM)](https://www.ibm.com/support/pages/aix-toolbox-linux-applications-overview)

You also need the `timeout` command. This requires the `coreutils` AIX Toolbox package.

In case you cannot install RPM packages on AIX (but Python is available) you can use the ``timeout`` binary in this directory. It is the timeout command from coreutils 9.5 (`coreutils-9.5-1.aix7.1.ppc.rpm`)
