# .dotfiles

My aliases repo.

## Installation

### Install with script

1. Clone the repository into `~/.dotfiles` folder:

    ```console
    cd ~ && git clone https://github.com/tdharris/.dotfiles.git .dotfiles
    ```

2. Enable aliases in the shell by adding to the `~/.bashrc` file:

    ```bash
    cd .dotfiles && ./install.sh
    ```

### Install manually

1. Clone the repository into `~/.dotfiles` folder:

    ```console
    cd ~ && git clone https://github.com/tdharris/.dotfiles.git .dotfiles
    ```

2. Enable aliases in the shell by adding the following to the `~/.bashrc` or `~/profile` file:

    ```console
    if [[ -f "~/.dotfiles/bootstrap.sh" ]]; then
        source ~/.dotfiles/bootstrap.sh
    fi
    ```

3. Enable in the current shell session by running the following command:

    ```console
    source ~/.dotfiles/bootstrap.sh
    ```
