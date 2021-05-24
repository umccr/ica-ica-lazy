# ICA-ICA-Lazy

TOC # TODO

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

If you do not have an account with Illumina you can create on [here][illumina_account_creation].

### Setting up the ica config

Once you have downloaded the binary file, you will need to make sure that you've made the binary an 'executable' 
and add it to your path. The following lines may assist you:

```shell
# Make the ica binary executable
chmod +x "${HOME}/Downloads/ica"
# Add binary to common bin path
sudo mv "${HOME}/Downloads/ica" "/usr/local/bin/ica"
```

### Configure ica

UMCCR links to ICA via sso (through our GSuite accounts).  

Run the configuration subcommand and respond to the prompts:

* `server-url` should be set to `aps.platform.illumina.com`
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

### Using this repo :construction:

Now it's time to set you up with this repo.  

Download the zip file from the [releases page][releases_page] :construction:
Unzip the file and run:
```bash
cd "iil-release-<version>"
bash install.sh
```

This will prompt you to add a few lines to your `~/.zshrc` and `~/.bashrc`

#### Setup

## Tokens management :construction:

This section entails:

1. `ica-refresh-access-token`
   * Refreshing an expired token
   * Set up of the tokens management section
   * For development, production and other projects
   * To be an automated process when tokens expire :construction:
2. `ica-context-switcher`
   * Change contexts by updating the `ICA_ACCESS_TOKEN` env var to that of your project
   * Does NOT require login

## Folder / file traversal :construction:

This section entails:

1. Using `gds-ls` 
   * for traversing the gds file system
2. Using `gds-view` 
   * for observing files without first downloading them

### `gds-ls`
> auto-completion :white_check_mark:
 
### `gds-view`
> auto-completion: :construction:

## Data sharing scripts :construction:

This section entails:

1. Using `gds-sync-download`
   * For syncing a gds folder with a local path
2. Using `gds-sync-upload`
   * For syncing a local path with a gds folder

### `gds-sync-download` :construction:
> auto-completion: :construction:


### `gds-sync-upload` :construction:
> auto-completion: :construction:

## VIP - (Advanced scripts) :construction:
> auto-completion: :construction:

This section entails:

1. Running [illumination][illumination]


[illumina_account_creation]: https://login.illumina.com/platform-services-manager/#/
[ica_binary_download]: https://sapac.support.illumina.com/downloads/illumina-connected-analytics-cli-v1-0.html
[ica_landing_page]: https://umccr.login.illumina.com/#/home
[password_store]: https://www.passwordstore.org/
[illumination]: https://github.com/umccr/illumination
[pass_tutorial]: https://droidrant.com/notes-pass-unix-password-manager/