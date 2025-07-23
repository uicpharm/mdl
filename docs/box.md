# Support for Box.com

The Moodle scripts can use a Box.com account to store backup sets in the cloud. These
instructions will explain how to set up Box.com integration and how to use it with the
scripts that can leverage it.

## Setup on Box.com

Before you can begin, you must create an app integration on your Box.com account.

1. Login to [developer.box.com](https://developer.box.com) and click on
   [My Apps](https://account.box.com/developers/console).
2. Create a new custom app.
3. For authentication method, choose "User Authentication (OAuth 2.0)".
4. Copy the Client ID and Client Secret. You'll need to save them to the `.env` file.
5. Set the redirect URI to an address where you can collect the authentication token. If
   you don't have one, you can use <https://mdl.docs.uicpharm.dev/auth/callback/> which we
   provide only for your convenience and we do not record your tokens with it.
6. Check "Write all files and folders stored in Box".

Save the settings.

## Setup Moodle Environment

In your Box.com account, create/choose the folder where you want to store the backup
files. If you have multiple Moodle environments, you *can* save them all to the same
folder, but you can save to separate folders if you prefer. Copy the Folder ID as it is
seen in the URL when you navigate to the folder on Box.com. For instance, for a folder
at <https://app.box.com/folder/12345>, the Folder ID would be `12345`.

In the Moodle environment, add the following values:

   - `BOX_CLIENT_ID`: The Client ID you copied from the Box.com configuration.
   - `BOX_CLIENT_SECRET`: The Client Secret you copied from the Box.com configuration.
   - `BOX_REDIRECT_URI`: The redirect URI you set in the Box.com configuration.
   - `BOX_FOLDER_ID`: The numeric ID of the Box folder you selected.

You can use the same Client ID, secret, redirect URI, and Folder ID for multiple
environments if you want, but you must fill them in for each environment.

Once the `.env` settings have been entered, you can initiate the OAuth authorization.
This is very simple to accomplish. Just run:

```bash
mdl box $mname auth
```

This will generate a URL. Navigate to this URL and login and authorize your environment
with Box.com. It will provide you an authorization code. Copy the code and enter it into
the CLI prompt. You're done! You can now perform other box commands with `mdl box`.

The authorization saves two files in your environment: `box_access_token.txt` and
`box_refresh_token.txt`. These tokens will be regularly refreshed as needed when they
expire.

If you want to manually refresh the tokens, you can do so:

```bash
mdl box $mname refresh
```

An access token lasts for 60 minutes. If the token has expired, `mdl box` commands will
detect that and issue a refresh and retry the command. Refresh tokens expire after 60
days. So, if there is no activity for more than 60 days, you will have to reauthorize
with the `mdl box $mname auth` command. This expiration can easily be avoided if you have
a scheduled task that runs with a frequency of less than 60 days.

## Commands

You can perform `list`, `download`, and `upload` commands with `mdl box`. However, you
don't typically need to execute `mdl box` commands directly after authorization. That's
because you can essentially use Box functionality with the `mdl ls` or `mdl status`,
`mdl cp`, and `mdl restore` commands.

### `mdl ls` and `mdl status`

If you add `--box`, to these commands, they will include Box files in their report.

```bash
mdl status $mname --box
```

### `mdl cp`

When you use `--box`, this script will copy a backup set to Box, essentially uploading
the files.

```bash
mdl cp $mname my-label --box
```

### `mdl restore`

When you use `--box`, this script will restore a backup set, but it will download it from
Box first.

```bash
mdl restore $mname my-label --box
```
