-- This is an example function you can use on any option supporting colors
-- to use a random color instead.
function getRandomColor()
    math.randomseed()

    local r = math.random(0, 255)
    local g = math.random(0, 255)
    local b = math.random(0, 255)

    local col = b
    col = bit.bor(col, bit.lshift(g, 8))
    col = bit.bor(col, bit.lshift(r, 16))

    return col
end

ly = {
    -- Ly supports 24-bit true color with styling, which means each color is a 32-bit value.
    -- The format is 0xSSRRGGBB, where SS is the styling, RR is red, GG is green, and BB is blue.
    -- See res/config.lua upstream for the full styling bit reference.

    -- Allow empty password or not when authenticating
    allow_empty_password = true,

    -- The active animation
    animation = "matrix",

    -- Delay between each animation frame in milliseconds
    animation_frame_delay = 5,

    -- Stop the animation after some time (0 = run forever)
    animation_timeout_sec = 0,

    -- The character used to mask the password
    asterisk = '*',

    -- The number of failed authentications before a special animation is played
    auth_fails = 10,

    -- Automatic login configuration (both unset here, same as before)
    auto_login_service = "ly-autologin",
    auto_login_session = nil,
    auto_login_user = nil,

    -- Identifier for battery whose charge to display at top left.
    -- Unused on FreeBSD (hw.acpi.battery.life via sysctl is used directly instead) -
    -- this is why the custom FreeBSD battery patch built earlier turned out to be
    -- redundant with what upstream already does natively.
    battery_id = nil,

    -- Background color id
    bg = 0x00000000,

    -- Big clock language/state
    bigclock = "en",
    bigclock_12hr = false,
    bigclock_seconds = false,

    -- Blank main box background
    blank_box = true,

    -- Border foreground color id
    border_fg = 0x00FFFFFF,

    -- Box position (centered, matches previous implicit behavior - this machine
    -- never customized a position before, so using upstream's default)
    box_position_h = 0.5,
    box_position_v = 0.5,

    -- Title to show at the top of the main box
    box_title = nil,

    -- Brightness commands - kept as previously configured (custom backlight tool,
    -- not upstream's default brightnessctl)
    brightness_down_cmd = "/usr/bin/backlight -q - 10%",
    brightness_down_key = "F5",
    brightness_up_cmd = "/usr/bin/backlight -q + 10%",
    brightness_up_key = "F6",

    -- Erase password input on failure
    clear_password = false,

    -- Clock format string in top right corner - unset, same as before
    clock = nil,

    -- CMatrix animation colors/codepoints
    cmatrix_fg = 0x0000FF00,
    cmatrix_head_col = 0x01FFFFFF,
    cmatrix_min_codepoint = 0x21,
    cmatrix_max_codepoint = 0x7B,

    -- Color mixing animation colors
    colormix_col1 = 0x00FF0000,
    colormix_col2 = 0x000000FF,
    colormix_col3 = 0x20000000,

    -- Screen corners - previous config had hide_key_hints/hide_keyboard_locks/
    -- hide_version_string all set to false (i.e. show everything), which is
    -- exactly what upstream's own default corner layout already does - no
    -- reconstruction needed, using the defaults directly.
    corner_bottom_left = "version",
    corner_bottom_right = "labels",
    corner_top_left = "shutdown,restart,britup,britdown,password battery",
    corner_top_right = "clock numlock,capslock",

    -- Horizontal limit for custom bind hints - unset, same as before
    custom_bind_width = nil,

    -- Custom sessions directory - kept as previously configured
    custom_sessions = "/usr/local/etc/ly/custom-sessions",

    -- Input box active by default on startup
    default_input = "login",

    -- DOOM animation settings
    doom_fire_height = 6,
    doom_fire_spread = 2,
    doom_top_color = 0x009F2707,
    doom_middle_color = 0x00C78F17,
    doom_bottom_color = 0x00FFFFFF,

    -- Dur file settings
    dur_file_path = "/usr/local/etc/ly/example.dur",
    dur_offset_alignment = "center",
    dur_x_offset = 0,
    dur_y_offset = 0,

    -- Screen edge margin
    edge_margin = 0,

    -- Error colors
    error_bg = 0x00000000,
    error_fg = 0x01FF0000,

    -- pam_faillock tally directory - not previously configured, using upstream default
    faillock_tally_dir = "/var/run/faillock",

    -- Foreground color id
    fg = 0x00FFFFFF,

    -- Render true colors
    full_color = true,

    -- Game of Life settings
    gameoflife_entropy_interval = 10,
    gameoflife_fg = 0x0000FF00,
    gameoflife_frame_delay = 6,
    gameoflife_initial_density = 0.4,
    -- not previously configured (new options), using upstream defaults
    gameoflife_param_birth = "3",
    gameoflife_param_survival = "23",

    -- TTY to always grab focus on - unset, same as before
    grab_focus_tty = nil,

    -- Remove main box borders
    hide_borders = false,

    -- Inactivity command/delay - unset, same as before
    inactivity_cmd = nil,
    inactivity_delay = 0,

    -- Initial info line text - unset, same as before
    initial_info_text = nil,

    -- Input boxes length
    input_len = 34,

    -- Active language
    lang = "de",

    -- Login command - unset, same as before
    login_cmd = nil,

    -- login.defs path
    login_defs_path = "/etc/login.defs",

    -- Logout command - unset, same as before
    logout_cmd = nil,

    -- Lua animation file - not previously used (animation is "matrix"), using
    -- upstream default in case it's ever switched to "lua"
    lua_animation_file = "/usr/local/etc/ly/example.lua",

    -- General log file path
    ly_log = "/var/log/ly.log",

    -- Main box margins
    margin_box_h = 2,
    margin_box_v = 1,

    -- Numlock at startup
    numlock = false,

    -- Default PATH
    path = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",

    -- Restart key - shutdown_cmd/restart_cmd no longer exist as config options;
    -- ly now calls FreeBSD's native reboot(2) syscall directly
    -- (RB_POWEROFF/RB_AUTOBOOT) instead of shelling out to /sbin/shutdown -
    -- confirmed via source, no functionality lost by dropping the old commands.
    restart_key = "F2",

    -- Save file directory - previous config had `save = true` (a plain boolean,
    -- now removed); this is the equivalent explicit directory upstream's default
    -- boolean used to point at implicitly.
    save_file_dir = "/usr/local/etc/ly",

    -- Service name (pam config)
    service_name = "ly",

    -- Session log file path
    session_log = ".local/state/ly-session.log",

    -- Setup command
    setup_cmd = "/usr/local/etc/ly/setup.sh",

    -- Show the shell session in the list - not previously configured (new
    -- option), using upstream default
    shell = true,

    -- Show-password key - not previously configured (new option), using
    -- upstream default
    show_password_key = "F7",

    -- Shutdown key (see restart_key comment above re: shutdown_cmd removal)
    shutdown_key = "F1",

    -- Start command - unset, same as before
    start_cmd = nil,

    -- Center session name
    text_in_center = false,

    -- Manually type username - not previously configured (new option), using
    -- upstream default
    type_username = false,

    -- Vi mode
    vi_default_mode = "normal",
    vi_mode = false,

    -- Wayland sessions directory
    waylandsessions = "/usr/local/share/wayland-sessions",

    -- Xorg settings - kept for completeness even though this is a Wayland-only
    -- setup (enable_x11_support=false at build time already skips X11 session
    -- crawling regardless of what's configured here)
    x_cmd = "/usr/local/bin/X",
    x_vt = nil,
    xauth_cmd = "/usr/local/bin/xauth",
    xinitrc = "~/.xinitrc",
    xsessions = "/usr/local/share/xsessions",
}
