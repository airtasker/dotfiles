# Airtasker dotfiles

The Airtasker dotfiles is a simple repo that installs a selection of standard tools and also symlinks standard configuration files to system

## Setup
This is a quick guide to get your setup up and running!

1. Run bootstrap.sh script
    ```
    zsh -c "$(curl -fsSL https://raw.githubusercontent.com/airtasker/dotfiles/main/bootstrap.sh)"
    ```
2. Enter Github Email and Github Personal Access Token (classic)
    
    The script will prompt the user for their Github email. Once entered, the data is saved in ```~/environment/environment.zsh``` so that you don't need to be prompted again
    
    The script will also ask for a Github Personal Access Token (classic) which can be added here: https://github.com/settings/tokens
    The minimum required scope is:
      ```
      repo
      read:org
      write:public_key
      admin:ssh_signing_key
      read:packages
      ```
    Althogh more permissions may be useful if you plan to use the ```gh``` cli for other functions      

3. Configure P10K
    Open iTerm2 and run command below
    ```
    p10k configure
    ```

4. Post Install steps
    To install default asdf versions and other common brew packages
    ```
    install_asdf_defaults
    install_brew_defaults
    ```

### Adding variables, aliases and functions
Your ZSH environment will automatically scan any files ending with ```.sh``` ```.zsh``` ```.rc``` in your ```~/environment``` directory. So if you need to add a new environment variable, ensure it exists in ```~/environment```. 

A couple empty files have already been added like ```~/environment/aliases.zsh``` ready to receive your own aliases and functions. These files won't be tracked in git so you can use them to store secrets and other variables. 

For instance, I can edit ```~/environment/environment.zsh``` with 
```
export RANDOM_KEY=verysecure
```
You can open a new terminal or ```source ~/.zshrc``` then that variable will be sourced in your environment

If you do edit files in ```~/environment/dotfiles``` then those will be tracked by github as those have been symlinked to that directory from this repository.

### Using asdf 
```asdf``` is one of the tools installed by the bootstrap script. 
asdf is a version manager designed to support many different tools making it the one version manager to rule them all! 
asdf is really simple, first you need to make sure you have the plugin of the tool you want to install.

e.g. To install nodejs version 18.9.0 just run the following. 
```
asdf plugin add nodejs
asdf install nodejs 18.9.0
asdf global nodejs 18.9.0
```
Running the ```asdf global``` command will edit the ```~/.tool-versions``` file which contains the default versions for your system and running ```asdf local``` will edit your current directory ```.tool-versions``` file. Every time you change directory, asdf will check if a ```.tool-versions``` file exists, and if it does will use the versions defined in that file. 

If you enter a directory which has a ```.tool-versions``` file like this and then run ```asdf install``` it will check that file and install the versions defined here allowing you to get setup quickly
```
nodejs 18.9.0
ruby 3.1.2
```


### What does bootstrap script do? 
The bootstrap.sh sets up your mac for first use
* It installs brew and then uses brew to install more tools found in ```Brewfile```. 
* Creates new SSH key and uses the ```gh``` command line tool to add that key to your github account. (Script will prompt for Github Personal Access Token)
* Installs the ```asdf``` version manager tool and also installs the latest version of these tools
    * golang 
    * kubectl 
    * nodejs 
    * python 
    * ruby 
    * terraform
* Installs oh-my-zsh and powerlevel10k to make your terminal look great!
* Installs NvChad to make your vim spectactular
* Installs a great default tmux config 

### Dotfiles Structure
The dotfiles are powered by a tool called `stow`.
stow is a simple tool that creates symlinks of folders in the current directory and links them to the parent directory. 

The first directory like `asdf` is considered a package, and the files/folders in this directory are symlinked to the parent directory by default. So files like `asdf/.asdfrc` will be symlinked to `~/.asdfrc`. This is assuming this repo has been cloned to the home directory `~/dotfiles`

stow also manages directories, so if the configuration file needs to be symlinked into another directory, you can include those files by placing them in the expected directory structure. For instance, looking at the `environment` package, we have a file like `environment/environment/dotfiles/aliases.zsh` which will get symlinked to `~/environment/dotfiles/aliases.zsh`

**Source structure** ~/dotfiles
```
├── asdf
│   └── .asdfrc
├── dotfiles
|   ├── .editorconfig
│   └── .hushlogin
├── environment
│   └── environment
│       └── dotfiles
|           ├── aliases.zsh
|           ├── environment.zsh
|           └── functions.zsh
```
**Output structure** ~ (home directory)
```
├── .asdfrc
|── .editorconfig
│── .hushlogin
│── environment
│   └── dotfiles
|       ├── aliases.zsh
|       ├── environment.zsh
|       └── functions.zsh
```
