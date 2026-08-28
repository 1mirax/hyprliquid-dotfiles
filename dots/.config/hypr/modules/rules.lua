-- Window and layer rules.

hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ match = { class = "^(pavucontrol|nm-connection-editor|blueman-manager)$" }, float = true })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })
hl.window_rule({ match = { class = "^(nemo)$", title = "^(Properties)$" }, float = true })
-- No opacity rule for kitty: transparency comes from background_opacity in
-- kitty.conf. Stacking both would multiply and wash the text out.
-- No opacity rule for nemo: the glass comes from ~/.config/gtk-3.0/gtk.css,
-- which keeps text opaque. A window rule would fade the text along with it.
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- blur_popups covers the bar's own tooltips and dropdowns (the calendar on
-- the clock, the volume tooltip), which are separate surfaces.
hl.layer_rule({ match = { namespace = "waybar" }, blur = true, blur_popups = true })
hl.layer_rule({ match = { namespace = "notifications" }, blur = true, ignore_alpha = 0.1 })
-- fuzzel registers as "launcher", not "fuzzel" - verified by watching
-- hyprctl layers while it was open. A rule matching "fuzzel" never fired.
-- ignore_alpha must stay below the launcher's own 0.063 background alpha,
-- otherwise its most transparent parts are skipped by the blur.
-- The launcher animates like every other layer, but only because the monitor
-- runs at scale 1. fuzzel cannot know its final size before its surface is
-- mapped - the font size depends on the scale, which the compositor reports
-- afterwards - so it maps a placeholder frame and re-lays out once
-- wp_fractional_scale_v1 arrives (codeberg dnkl/fuzzel#463). At scale 1.5 that
-- meant set_size(354, 316) followed by set_size(344, 319) ~140 ms later, and
-- since a layer animation moves geometry, it chased the change and the right
-- edge visibly dragged. Styles do not dodge it: "fade" was tried both as the
-- global animation:layers style and as this rule's own, and the drag returned
-- both times. Upstream's answer is noanim.
--
-- At scale 1 fuzzel's initial guess is already correct - measured, one commit
-- at 354x324 instead of two - so there is nothing left to chase. If the
-- monitor ever goes back to a fractional scale, add no_anim = true here.
hl.layer_rule({ match = { namespace = "launcher" }, blur = true, ignore_alpha = 0.03 })
-- The cheatsheet is fuzzel in dmenu mode, launched with --namespace cheatsheet
-- so it can be told apart from the launcher. Same glass, same ignore_alpha
-- (the background is ffffff10, so the threshold has to sit below 0.063), plus
-- dim_around to push the desktop back while a list of keys is being read.
hl.layer_rule({ match = { namespace = "cheatsheet" },
  blur = true, ignore_alpha = 0.03, dim_around = true })
