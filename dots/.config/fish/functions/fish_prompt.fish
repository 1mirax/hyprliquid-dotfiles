# Fish's own "simple" preset - user@host, the path, and a plain $ - with the
# colours moved off the blue end of the palette.
#
# Deliberately minimal: no git segment, no exit code, no framing. What time it
# is and how long the last command took live in fish_right_prompt.

function fish_prompt --description 'Simple, in the rice palette'
    set -l symbol ' $ '
    set -l color $fish_color_cwd
    if fish_is_root_user
        set symbol ' # '
        set -q fish_color_cwd_root
        and set color $fish_color_cwd_root
    end

    set_color 6a6a70
    echo -n $USER@$hostname
    set_color normal

    set_color $color
    echo -n (prompt_pwd)
    set_color normal

    echo -n $symbol
end
