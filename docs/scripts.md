# Script Reference

This is a reference of all the scripts this project provides. Some of these scripts are
used internally by other scripts and not necessarily intended for direct execution. They
are listed at the bottom to make this reference easier to read.

## Main Scripts

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

### `mdl init`

<pre>{{ man['mdl-init'] }}</pre>

### `mdl install-plugin` (or `mdl install-plugins`)

<pre>{{ man['mdl-install-plugin'] }}</pre>

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
