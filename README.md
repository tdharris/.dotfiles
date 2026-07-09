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
    if [[ -f "$HOME/.dotfiles/bootstrap.sh" ]]; then
        source "$HOME/.dotfiles/bootstrap.sh"
    fi
    ```

3. Enable in the current shell session by running the following command:

    ```console
    source ~/.dotfiles/bootstrap.sh
    ```

## Bootstrap

`bootstrap.sh` has two modes:

1. Default mode sources shell dependencies and aliases.
2. Link-plan mode (`--apply-links`) applies symlink operations from plan files.

Preview link actions:

```console
~/.dotfiles/bootstrap.sh --apply-links --dry-run
```

Apply link actions:

```console
~/.dotfiles/bootstrap.sh --apply-links --force
```

`--force` is required only when an existing non-symlink target is handled with `if_exists: backup` or `if_exists: replace`.

## Link Plans

Bootstrap discovers plan files at:

1. `~/.dotfiles/wrk/bootstrap.plan.yml`
2. `~/.dotfiles/personal/bootstrap.plan.yml`

Typical usage is to keep private AI assistant files in a private submodule and link them into an editor user profile path.

Example `bootstrap.plan.yml` using directory-based linking:

```yaml
version: 1
operations:
  - op: symlink_tree
    source_dir: copilot/instructions
    target_dir: ~/.config/Code/User/instructions
    include:
      - "*.instructions.md"
    if_exists: backup
```

Example single-file operation:

```yaml
version: 1
operations:
  - op: symlink
    source: copilot/instructions/ai-workflow.instructions.md
    target: ~/.config/Code/User/instructions/ai-workflow.instructions.md
    if_exists: backup
```

## Private Submodules

If private files are managed in submodules such as `~/.dotfiles/wrk`, update the submodule content before running `--apply-links`.

## Common Workflows

Add or update instruction files across devices:

1. Update source-of-truth files in your private repository.
2. Update the submodule pointer in `~/.dotfiles`.
3. Pull on another device and update submodules.
4. Run `~/.dotfiles/bootstrap.sh --apply-links --dry-run`.
5. Run `~/.dotfiles/bootstrap.sh --apply-links --force` if changes look correct.

Notes:

1. Existing symlinked files update automatically when source files change.
2. New files require `--apply-links` once on each device to create new symlinks.
