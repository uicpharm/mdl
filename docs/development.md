# Development Tips

This is a collection of tips to help you work on a development instance of the Moodle
environment with more ease and joy.

## Use Backups on Box

[Scheduled tasks](./schedtasks.md) are sending daily and monthly backups to
[Box](./box.md). You can take advantage of this automation to more easily update your
environment to match production without needing to connect to the VPN or put any load on
the server, by just using the Box support built into `mdl restore`.

For instance, restore the latest `daily` backup of `mymoodle` on Box:

```bash
# Restore from the latest daily backup on Box
mdl restore mymoodle daily --box
```

## Expediting Restores

When you are developing, sometimes you want to repetitively restore the environment to a
fresh state. There may be file or database changes you want to restore. The standard
restore can be slower than preferred due to 2 factors: (a) Restoring the large archives
can be slow, especially when they're compressed, and (b) When you start the container, the
database then has to be fully restored from `backup.sql`.

### Store uncompressed backup sets

By default, backup sets are stored as bzip2 files. You can either perform your backup with
the `--compress none` option, or if you are downloading from Box, you can restore with the
`--extract` option, to leave an extracted version of the backup. From then on, your
restore will go much faster since it will be an uncompressed tar file.

For instance:

```bash
# Download from box and leave an extracted copy of the backup
mdl restore all daily --box --extract
```

### Use a Fast DB Backup

The `mdl fast-db-backup` and `mdl fast-db-restore` commands make a tar archive of the
actual database files themselves, meaning the `backup.sql` dump file does not have to be
restored when the container starts for the first time. Whereas this is unsafe for
production, it saves time and works well in a development environment.

I usually use a process like this when working:

```bash
# Initially restore a backup set, including full startup:
mdl restore all daily && mdl start all --wait
# You optionally may want to apply any dev configs:
mdl config all
# Perform the fast db backup:
mdl fast-db-backup all dev

# ... do your development work ...

# Perform a restore and fast db restore to reset:
mdl restore all daily && mdl fast-db-restore all dev && mdl start all
```

Using this restore workflow, the container is usually functioning within seconds. Things
will obviously go even faster if you run these commands on just one environment instead of
`all`.

## Use Developer Configs

When you restore a production environment to a staging or development instance, you
already should [update your .env file](./getting-started.md#migrate-a-server) to ensure
you don't unintentionally send data to CPE Monitor.  However, you can also set many other
configs in such a way to benefit your developer experience.

Here is a collection of configs you could add to your `.env` file:

<!-- markdownlint-disable -->
<!-- spell-checker: disable -->
```dotenv
# Developer Configurations
smtphosts=sandbox.smtp.mailtrap.io:587
smtpsecure=tls
smtpuser=your-mailtrap.io-username
smtppass=your-mailtrap.io-password
debug=32767
perfdebug=15
debugstringids=1
debugpageinfo=1
updateautocheck=0
sessiontimeout=2592000
maintenance_enabled=0
tempdatafoldercleanup=3
additionalhtmltopofbody='<style>@media print{.stg{display:none!important}}</style><div class="stg" style="z-index:1050;position:fixed;display:flex;text-align:center;align-items:center;color:yellow;font-weight:bold;width:255px;height:60px;top:0;left:50%;margin-left:-123px;">Staging Server</div><script>fetch("/last_refresh.txt").then(response=>response.ok?response.text():'').then(data=>{if(data)document.querySelector(".stg").innerHTML+=" last refreshed on "+data})</script>'
cachetemplates=0
```
<!-- spell-checker: enable -->
<!-- markdownlint-enable -->

To apply these configurations to your local instance, add them to your `.env` file and
then run:

```bash
# Applies any configs in .env to your environments
mdl config all
```
