# Script Reference

## Moodle Shortcut Script: `mdl`

There is a shortcut script in `bin` called `mdl`. With it, you can use `mdl` from anywhere
to more easily call your scripts. For instance:

```sh
# Instead of '/data/moodle/start.sh mymoodle', you could just type:
mdl start mymoodle

# Instead of '/data/moodle/upgrade.sh mymoodle', you could just type:
mdl upgrade mymoodle
```

### Install `mdl` in your system

The best way to use `mdl` on both workstations and servers is to install it into your
`/usr/bin` directory:

```sh
ln -s /data/moodle/bin/mdl /usr/bin/mdl
```

Alternatively, if you will not be running as a superuser and you don't want to constantly
`sudo` all the commands, you could instead add a `mdl` alias to your own user profile,
such as `.zprofile` or `.bashrc`:

```sh
alias mdl='sudo /data/moodle/bin/mdl'
```

## Scripts

This is a reference of all the scripts this project provides. Some of these scripts are
used internally by other scripts and not necessarily intended for direct execution. They
are listed at the bottom to make this reference easier to read.

### `mdl backup` (or `mdl bk`)

<pre>{{ man['mdl-backup'] }}</pre>

### `mdl box`

<pre>{{ man['mdl-box'] }}</pre>

### `mdl cli`

<pre>{{ man['mdl-cli'] }}</pre>

### `mdl config` (or `mdl cfg`)

<pre>{{ man['mdl-config'] }}</pre>

### `mdl copy` (or `mdl cp`)

<pre>{{ man['mdl-copy'] }}</pre>

### `mdl exec-sql`

<pre>{{ man['mdl-exec-sql'] }}</pre>

### `mdl fast-db-backup`

<pre>{{ man['mdl-fast-db-backup'] }}</pre>

### `mdl fast-db-restore`

<pre>{{ man['mdl-fast-db-restore'] }}</pre>

### `mdl info`

<pre>{{ man['mdl-info'] }}</pre>

### `mdl install-customizations`

<pre>{{ man['mdl-install-customizations'] }}</pre>

### `mdl list` (or `mdl ls`)

<pre>{{ man['mdl-list'] }}</pre>

### `mdl logs`

<pre>{{ man['mdl-logs'] }}</pre>

### `mdl remove` (or `mdl rm`)

<pre>{{ man['mdl-remove'] }}</pre>

### `mdl rename`

<pre>{{ man['mdl-rename'] }}</pre>

### `mdl resetpassword`

<pre>{{ man['mdl-resetpassword'] }}</pre>

### `mdl restore`

<pre>{{ man['mdl-restore'] }}</pre>

### `mdl start`

<pre>{{ man['mdl-start'] }}</pre>

### `mdl status`

<pre>{{ man['mdl-status'] }}</pre>

### `mdl stop`

<pre>{{ man['mdl-stop'] }}</pre>

### `mdl tunnel`

<pre>{{ man['mdl-tunnel'] }}</pre>

### `mdl upgrade`

<pre>{{ man['mdl-upgrade'] }}</pre>

## Internal-use Scripts

These scripts are used in this project but not necessarily needed for direct execution.
Documented here just for thoroughness.

### `active-env.sh`

<pre>{{ man['mdl-active-env'] }}</pre>

### `calc-compose-path.sh`

<pre>{{ man['mdl-calc-compose-path'] }}</pre>

### `calc-images.sh`

<pre>{{ man['mdl-calc-images'] }}</pre>

### `export-env.sh`

<pre>{{ man['mdl-export-env'] }}</pre>

### `moodle-version.sh`

<pre>{{ man['mdl-moodle-version'] }}</pre>

### `select-env.sh`

<pre>{{ man['mdl-select-env'] }}</pre>

### `touch-env.sh`

<pre>{{ man['mdl-touch-env'] }}</pre>

<script setup>
const man = __SCRIPT_MAN_PAGES__;
</script>

<style>
/* Script docs stretch 90 chars wide. Make sure they fit without going under side nav. */
pre {
   font-size: 0.88em;
}
</style>
