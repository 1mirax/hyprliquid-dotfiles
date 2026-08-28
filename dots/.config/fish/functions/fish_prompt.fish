# Two-line prompt in the illogical-impulse spirit:
# path and git state on top, a bare chevron to type against below.
# Pure fish - no starship, no extra processes beyond git.

function fish_prompt --description 'Liquid glass prompt'
    set -l last_status $status

    # Remote sessions get a visible marker
    if set -q SSH_TTY
        set_color --bold ff9f0a
        printf '%s ' (prompt_hostname)
        set_color normal
    end

    # Working directory
    set_color --bold 0a84ff
    printf '%s' (prompt_pwd)
    set_color normal

    # Git branch and dirty flag
    if command -sq git
        set -l branch (command git symbolic-ref --short HEAD 2>/dev/null)
        # Detached HEAD: fall back to the short hash
        if test -z "$branch"
            set branch (command git rev-parse --short HEAD 2>/dev/null)
        end

        if test -n "$branch"
            set_color bf5af2
            printf '  %s' $branch
            if not command git diff --no-ext-diff --quiet 2>/dev/null
                or not command git diff --no-ext-diff --cached --quiet 2>/dev/null
                set_color ffd60a
                printf ' ●'
            end
            set_color normal
        end
    end

    printf '\n'

    # Chevron turns red when the previous command failed
    if test $last_status -eq 0
        set_color --bold f5f5f7
    else
        set_color --bold ff453a
    end
    printf '❯ '
    set_color normal
end
