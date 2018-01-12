# Imaging Shell Scripts

Exported from ~sudas/DARPA/scripts on Rhino, and depends on scripts and
binaries in ~sudas.


## Emails on job completion

Three scripts have the option to email the user when they complete:
```mtlseg.sh```, ```wholebrainseg.sh```, and ```runpipeline.sh```.
```mtlseg.sh``` and ```runpipeline.sh``` send mail to the user's account
on rhino by default, while ```wholebrainseg.sh``` does not send mail by
default. In all three cases, calling the script with ``` -M email@host```
will send an email to the address specified when the script finishes running.