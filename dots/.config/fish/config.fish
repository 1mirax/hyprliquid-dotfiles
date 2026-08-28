# iOS liquid glass - palette shared with kitty / waybar / fuzzel / mako.

set -g fish_greeting ''

if status is-interactive
    # --- Syntax colors (iOS system palette, no default green) ---
    # Two separate systems, on purpose.
    #
    # The greys are the ground and stay quiet - a five-step ladder with
    # nothing between the steps. They are true neutrals: #aaa1af was tried as
    # the base and it tinted whole screens of output violet, which is fine on
    # a filename and wearing everywhere else.
    #
    #   4a4a53  ghost      what has not been typed yet
    #   6a6a70  recessive  comments, and the path in the prompt
    #   8b8b93  structure  operators, options, terminators
    #   b9b9c1  text       the base tone - arguments and ordinary output
    #   e8e8ec  emphasis   the command being run
    #
    # The hued colours are not on that ladder and are not muted to match it.
    # Colour is what carries meaning here, so it is saturated enough to read
    # as colour rather than as another grey. Blue and cyan are the exception,
    # kept near-neutral because they grate.
    set -g fish_color_normal          b9b9c1
    set -g fish_color_command         e8e8ec
    set -g fish_color_keyword         c3a56d
    set -g fish_color_quote           88a37c
    set -g fish_color_redirection     c3a56d
    set -g fish_color_end             8b8b93
    set -g fish_color_error           c26873
    set -g fish_color_param           b9b9c1
    set -g fish_color_comment         6a6a70
    set -g fish_color_operator        8b8b93
    set -g fish_color_escape          c3a56d
    set -g fish_color_option          967aa7
    set -g fish_color_autosuggestion  4a4a53
    set -g fish_color_cwd             6a6a70
    set -g fish_color_user            b9b9c1
    set -g fish_color_host            b9b9c1
    set -g fish_color_selection       --background=32323a
    set -g fish_color_search_match    --background=32323a
    set -g fish_pager_color_prefix       e8e8ec --bold
    set -g fish_pager_color_completion   b9b9c1
    set -g fish_pager_color_description  6a6a70
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
