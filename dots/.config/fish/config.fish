# iOS liquid glass - palette shared with kitty / waybar / fuzzel / mako.

set -g fish_greeting ''

if status is-interactive
    # --- Syntax colors (iOS system palette, no default green) ---
    set -g fish_color_normal          f5f5f7
    set -g fish_color_command         64d2ff
    set -g fish_color_keyword         bf5af2
    set -g fish_color_quote           ffd60a
    set -g fish_color_redirection     64a8ff
    set -g fish_color_end             bf5af2
    set -g fish_color_error           ff453a
    set -g fish_color_param           f5f5f7
    set -g fish_color_comment         6a6a70
    set -g fish_color_operator        bf5af2
    set -g fish_color_escape          ff9f0a
    set -g fish_color_option          64a8ff
    set -g fish_color_autosuggestion  5a5a63
    set -g fish_color_cwd             0a84ff
    set -g fish_color_user            64d2ff
    set -g fish_color_host            f5f5f7
    set -g fish_color_selection       --background=3a3a42
    set -g fish_color_search_match    --background=3a3a42

    # --- Completion pager ---
    set -g fish_pager_color_prefix       64d2ff --bold
    set -g fish_pager_color_completion   f5f5f7
    set -g fish_pager_color_description  6a6a70
    set -g fish_pager_color_selected_background --background=3a3a42

    # Full path in the prompt instead of the f/b/shortened form
    set -g fish_prompt_pwd_dir_length 0

    # --- Abbreviations ---
    abbr -a -- ll 'ls -lah'
    abbr -a -- la 'ls -A'
    abbr -a -- gs 'git status'
    abbr -a -- gd 'git diff'
    abbr -a -- gl 'git log --oneline --graph --decorate -20'
    abbr -a -- hyprlog 'journalctl --user -u hyprland -f'

    # --- Environment ---
    # Pick whichever editor is actually installed (nvim is not, yet)
    if command -sq nvim
        set -gx EDITOR nvim
    else
        set -gx EDITOR nano
    end
    set -gx VISUAL $EDITOR
    set -gx MANPAGER 'less -R'

    # --- Prompt ---
    # starship takes over when installed (it defines fish_prompt itself,
    # which wins over the autoloaded function). Until then the native
    # fish_prompt in functions/ is used, so nothing breaks either way.
    if command -sq starship
        set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
        starship init fish | source
    end
end
