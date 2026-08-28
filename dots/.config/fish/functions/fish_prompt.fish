# Fish's own "simple" preset - user@host, the path, a plain $ - in the grey
# ladder from config.fish.
#
# The prompt runs the other way round from most: user@host and the $ sit at
# the text tone while the path recedes, so the prompt reads as one quiet frame
# around the one thing worth reading.
#
# A frosted-glass prompt was tried and cannot be done. A terminal draws glyphs
# opaque - kitty takes six-digit hex, there is no alpha on text - and the dim
# attribute, the only real blending on offer, mixes toward the background
# COLOUR rather than toward what is behind the window, so it just yields
# another grey. kitty's dim_opacity tunes how much, not what.
#
# Checked rather than assumed: no terminal exposes alpha on glyphs. Contour's
# foreground_alpha, which sounds like it, applies to selection and search
# highlights, not to text. The transparency in this window lives underneath
# the text and always will. Doing it properly means a GTK or Quickshell
# overlay, which is a separate program, not a shell prompt.

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
