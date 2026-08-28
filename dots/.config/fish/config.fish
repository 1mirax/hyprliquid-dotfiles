# iOS liquid glass - palette shared with kitty / waybar / fuzzel / mako.

set -g fish_greeting ''

if status is-interactive
    # --- Syntax colors (iOS system palette, no default green) ---
    # Neutral palette, matching kitty's. Tokens are told apart by lightness
    # and a faint temperature bias, not by hue: commands are the brightest
    # thing on the line, arguments plain, everything structural dimmer.
    # Red is the only saturated colour left, and it means something went wrong.
    set -g fish_color_normal          d8d8de
    set -g fish_color_command         e8e8ec
    set -g fish_color_keyword         a99d87
    set -g fish_color_quote           8d9689
    set -g fish_color_redirection     a99d87
    set -g fish_color_end             928a97
    set -g fish_color_error           b4767d
    set -g fish_color_param           b9b9c1
    set -g fish_color_comment         55555f
    set -g fish_color_operator        928a97
    set -g fish_color_escape          a99d87
    set -g fish_color_option          9ca9a7
    set -g fish_color_autosuggestion  4a4a53
    set -g fish_color_cwd             b9b9c1
    set -g fish_color_user            859290
    set -g fish_color_host            8d9689
    set -g fish_color_selection       --background=32323a
    set -g fish_color_search_match    --background=32323a
    set -g fish_pager_color_prefix       e8e8ec --bold
    set -g fish_pager_color_completion   b9b9c1
    set -g fish_pager_color_description  55555f
    set -g fish_pager_color_selected_background --background=32323a

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
    # Starship is installed but not initialised: it replaces fish_prompt, and
    # the prompt here is the hand-written one in functions/fish_prompt.fish.
    # Uncomment to hand the prompt back to starship.
    #
    # if command -sq starship
    #     set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
    #     starship init fish | source
    # end
end
