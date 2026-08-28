# Right prompt: how long the last command took, muted.
# Only shows up past 2s so it stays quiet during normal work.

function fish_right_prompt --description 'Command duration'
    if test $CMD_DURATION -gt 2000
        set -l secs (math -s1 $CMD_DURATION / 1000)
        set_color 6a6a70
        if test $CMD_DURATION -gt 60000
            set -l mins (math -s0 $CMD_DURATION / 60000)
            set -l rest (math -s0 "($CMD_DURATION % 60000) / 1000")
            printf '%sm %ss' $mins $rest
        else
            printf '%ss' $secs
        end
        set_color normal
    end
end
