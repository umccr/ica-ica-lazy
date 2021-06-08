# ICA-ICA-Lazy <!-- omit in toc -->

- [Vanilla (Getting started)](#vanilla-getting-started)
  - [Downloading the ica binary](#downloading-the-ica-binary)
  - [Setting up the ica config](#setting-up-the-ica-config)
  - [Configure ica](#configure-ica)
  - [Logging in to ica](#logging-in-to-ica)
  - [Navigating the cli](#navigating-the-cli)
  - [Creating an api-key](#creating-an-api-key)
  - [Saving your api-key](#saving-your-api-key)
  - [Using this repo](#using-this-repo)
    - [Setup](#setup)
- [Tokens management](#tokens-management)
  - [ica-add-access-token](#ica-add-access-token)
  - [ica-context-switcher](#ica-context-switcher)
- [Folder / file traversal](#folder--file-traversal)
  - [`gds-ls`](#gds-ls)
  - [`gds-view`](#gds-view)
- [Data sharing scripts](#data-sharing-scripts)
  - [`gds-sync-download`](#gds-sync-download)
  - [`gds-sync-upload`](#gds-sync-upload)
- [VIP - (Advanced scripts) :construction:](#vip---advanced-scripts-construction)

## Vanilla (Getting started)

This section entails:
1. Downloading the ica binary
2. Setting up the ica config
3. Logging in to ica
4. Creating an api-key
5. Securely saving your api-key
6. Set up of this repository

### Downloading the ica binary

You may download the ica binary from [here][ica_binary_download].   

> Please make sure you're logged in with your Illumina account (see top right hand corner).
> This account is separate to your GSuite account

If you do not have an account with Illumina you can create one [here][illumina_account_creation].

### Setting up the ica config

Once you have downloaded the binary file, you will need to make sure that you've made the binary an 'executable' 
and add it to your path. The following lines may assist you:

```shell
# Use wget to download the url
wget --output-document ica.zip "<presigned_url>"
# Unzip the download
unzip ica.zip
# Make the ica binary executable
chmod +x "${HOME}/Downloads/ica"
# Add binary to common bin path
sudo mv "${HOME}/Downloads/ica" "/usr/local/bin/ica"
```

### Configure ica

UMCCR links to ICA via sso (through our GSuite accounts).  

Run the configuration subcommand and respond to the prompts:

* `server-url` should be set to `aps2.platform.illumina.com`
* `domain` should be set to `umccr`
* `output-format` either 'table' or 'json'

```shell
ica config set  # Then respond to prompts above
```

This will create a file at `${HOME}/.ica/config.yaml`

Since we run ica through our gsuite account we will need to also add `sso: true` to our config file.  
The script below may help you

```shell
echo "sso: true" >> "${HOME}/.ica/config.yaml"
```

### Logging in to ica

It's now time to log in to the cli with the following command:

```shell
ica login 
```

This will open up a firefox browser. Enter your GSuite credentials.  

### Navigating the cli

You will now be able to ping the ICA api through the ica binary. Yay!  

Try out the following commands. 

```shell
ica projects list
ica workgroups list
```

Workgroups are a collection of users while projects contain all of your workflows and data.

A project can be configured to allow users of a given workgroup to have 'read-only', 'contributor' or 'admin' access.

A user's privilege in a given project context will be the union of their workgroups privileges for that project.

### Creating an api-key

An api-key is very handy for service users or those of us that do not want to have to log in every day.  
Currently, we can create 'long-lasting' (three month) tokens by providing an api-key.  

Head over to our [landing page][ica_landing_page].   
In the top right corner click on your name/ID and select 'Manage API Keys' from your menu.

Create an api-key for your workgroup context (say development).  
Do NOT close the browser until reading the next section

### Saving your api-key

> Ideally one would create one api-key per workgroup, unfortunately scopes of api-keys aren't 
> respected by the token creation and are as stated above, will be a union of all of a user's workgroups 
> privileges for a given project. We are hoping this changes in a future release and are still setting up accordingly.


Use [pass][password_store] to store your api-keys under the following hierarchy -> this needs to be done in order to 
use the 'tokens-management' section below.  

> If you're unfamiliar with pass, please see [this tutorial][pass_tutorial] before continuing

```shell
pass add "/ica/api-keys/<workgroup>"
```

To test your api-key saving ability we will try the following code:

```shell
ica tokens create --project-name "development" --api-key "$(pass "/ica/api-keys/development")"
```

If a whole bunch of random letters and numbers came up on your terminal, congrats! You can move on to the next section.

:warning:
You must also save a 'personal' (by checking all workgroup contexts) api-key under `/ica/api-keys/default-api-key`.  
While the scripts below are based off a 1:1 mapping between workgroups and projects, there will be some projects that
do not have an associated workgroup. Since for this ICA release, token creation doesn't depend on the scope on the api-key
we can fall back on this api-key (default-api-key) in the event there is no set workgroup for a given project.   

### Using this repo

Now it's time to set you up with this repo.  

Download the zip file from the [releases page][releases_page]
Unzip the file and run:
```bash
cd "release-<version>"
bash install.sh
```

This will prompt you to add a few lines to your `~/.zshrc` (MacOS users) or `~/.bashrc` (Linux or WSL users)

## Tokens management

This section entails:

1. `ica-add-access-token`
   * Retrieves api-key from pass db
   * Requires project name and scope as input
   * Writes token to `~/.ica-ica-lazy/tokens/tokens.json`
   * 
2. `ica-context-switcher`
   * Change contexts by updating the `ICA_ACCESS_TOKEN` env var to that of your project
   * Does NOT require login
   
### ica-add-access-token
> Autocompletion: :white_check_mark:

This command will update your token for a given project under `~/.ica-ica-lazy/tokens/tokens.json`.  
Pleas make sure you've read the [Saving your api key](#saving-your-api-key) section before trying.

*To verify, you've successfully completed said section, please run `pass /ica/api-keys/default-api-key`.  
One would expect this to return your personal api key.*

**Options:**
  * --project-name: The name of your project
  * --scope: Do you want to enter this context with 'admin' or 'read-only' privileges

**Requirements:**
  * curl
  * jq
  * pass

**Environment vars:**
  * ICA_BASE_URL


### ica-context-switcher
> Autocompletion: :white_check_mark:

Update the `ICA_ACCESS_TOKEN` env var in your current console window with that of a stored token under
`~/.ica-ica-lazy/tokens/tokens.json`.  You **MUST** have first added the token to the secret file with `ica-add-access-token` script.  

**Options:**
  * --project-name: The name of your project
  * --scope: Do you want to enter this context with 'admin' or 'read-only' privileges

**Requirements**
  * curl
  * jq

## Folder / file traversal

This section entails:

1. Using `gds-ls` 
   * for traversing the gds file system
2. Using `gds-view` 
   * for observing files without first downloading them

### `gds-ls`
> auto-completion :white_check_mark:

Run ls on a GDS file system as if it were your local system.  

**Options:**
  * folder-path: Single positional argument.

**Requirements:**
  * curl
  * jq
  * python3

**Environment vars:**
  * ICA_BASE_URL
  * ICA_ACCESS_TOKEN

 
### `gds-view`
> auto-completion :white_check_mark:

View a gds file without first needing to download it.  
Works for gzipped files too.  Uses the links program (through docker) to
visualise the file.  

**Options:**
  * --gds-path: Path to the gds file you wish to view.

**Requirements:**
  * curl
  * jq
  * python3
  * docker

**Environment vars:**
  * ICA_BASE_URL
  * ICA_ACCESS_TOKEN

## Data sharing scripts

This section entails:

1. Using `gds-sync-download`
   * For syncing a gds folder with a local path
2. Using `gds-sync-upload`
   * For syncing a local path with a gds folder
 
### `gds-sync-download`
> auto-completion: :white_check_mark:

Sync a gds folder with a local directory using the temporary aws creds
in a given gds folder.  This function requires admin privileges in the source project.  

**Options:**  
  * --gds-path:  Path to the gds folder
  * --download-path:  Path to your local directory

**Requirements:**
  * curl
  * jq
  * python3  
  * aws

**Environment vars:**
  * ICA_BASE_URL
  * ICA_ACCESS_TOKEN

**Extra info:**

*  You can also use any of the aws s3 sync parameters to add to the command list, for example:
   ```
   gds-sync-download --gds-path gds://volume-name/path-to-folder/ --exclude='*' --include='*.fastq.gz'
   ```
   will download only fastq files from that folder.
           
   * If you are unsure on what files will be downloaded, use the `--dryrun` parameter. This will inform you of which
     files will be downloaded to your local file system.
   
   * Unlike rsync, trailing slashes on the `--gds-path` and `--download-path` do not matter. One can assume that
     a trailing slash exists on both parameters. This means that the contents inside the `--gds-path` parameter are
     downloaded to the contents inside `--download-path`

### `gds-sync-upload`
> auto-completion: :white_check_mark:

Sync a local directory with a gds folder using the temporary aws creds in a given gds folder.  
This function requires admin privileges in the destination project.  

**Options:**  
  * --src-path:  Path to your local directory
  * --gds-path:  Path to the gds folder

**Requirements:**
  * curl
  * jq
  * python3  
  * aws

**Environment vars:**
  * ICA_BASE_URL
  * ICA_ACCESS_TOKEN

## VIP - (Advanced scripts) :construction:
> auto-completion: :construction:

This section entails:

1. Running [illumination][illumination]  :construction:  

[releases_page]: https://github.com/umccr/ica-ica-lazy/releases
[illumina_account_creation]: https://login.illumina.com/platform-services-manager/#/
[ica_binary_download]: https://sapac.support.illumina.com/downloads/illumina-connected-analytics-cli-v1-0.html
[ica_landing_page]: https://umccr.login.illumina.com/#/home
[password_store]: https://www.passwordstore.org/
[illumination]: https://github.com/umccr/illumination
[pass_tutorial]: https://droidrant.com/notes-pass-unix-password-manager/