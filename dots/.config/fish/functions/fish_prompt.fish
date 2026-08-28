# Fish's own "simple" preset - user@host, the path, a plain $ - in the grey
# ladder defined in config.fish.
#
# Two shades only: the prompt itself is meta and sits at 6a6a70, the path is
# text and sits at b9b9c1. The $ matches user@host rather than standing on its
# own, so the whole prompt reads as one dim frame around one bright thing.

function fish_prompt --description 'Simple, in the grey ladder'
    set -l symbol ' $ '
    set -l color $fish_color_cwd
    if fish_is_root_user
        set symbol ' # '
        set -q fish_color_cwd_root
        and set color $fish_color_cwd_root
    end

    set_color $fish_color_user
    echo -n $USER@$hostname
    set_color normal

    set_color $color
    echo -n (prompt_pwd)
    set_color normal

    set_color $fish_color_user
    echo -n $symbol
    set_color normal
end
