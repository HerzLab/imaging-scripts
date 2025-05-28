# Imaging Shell Scripts

Exported from ~sudas/DARPA/scripts on Rhino in the Kahana CML, and depends on scripts and
binaries in ~sudas.


## Emails on job completion

Three scripts have the option to email the user when they complete:
```mtlseg.sh```, ```wholebrainseg.sh```, and ```runpipeline.sh```. The
syntax of these commands is now:

```bash
COMMAND_NAME [-M email_address] ARGS
```

Note that the ```-M``` option must come before any non-optional arguments.

To see a usage message, use either of the following forms:
```bash
COMMAND_NAME
COMMAND_NAME -h
```