local config = {
    OutDec              = ".",
    Rout_more_colors    = false,
    R_app               = nil,
    R_cmd               = nil,
    R_path              = nil,
    RStudio_cmd         = nil,
    rnvim_home          = nil,
    user_login          = nil,
    R_args              = {},
    after_ob_open       = {},
    after_start         = {},
    applescript         = false,
    arrange_windows     = true,
    assign              = true,
    assign_map          = "<M-->",
    auto_scroll         = true,
    auto_start          = 0,
    bracketed_paste     = false,
    buffer_opts         = "winfixwidth winfixheight nobuflisted",
    clear_console       = true,
    clear_line          = false,
    close_term          = true,
    dbg_jump            = true,
    debug               = true,
    debug_center        = false,
    disable_cmds        = {''},
    editor_w            = 66,
    esc_term            = true,
    external_term       = false, -- might be a string
    fun_data_1          = {'select', 'rename', 'mutate', 'filter'},
    fun_data_2          = {ggplot = {'aes'}, with = '*'},
    help_w              = 46,
    hi_fun_paren        = false,
    insert_mode_cmds    = false,
    latexcmd            = {"default"},
    listmethods         = false,
    min_editor_width    = 80,
    non_r_compl         = true,
    config_tmux         = true,
    nvim_wd             = 0,
    nvimpager           = "vertical",
    objbr_allnames      = false,
    objbr_auto_start    = false,
    objbr_h             = 10,
    objbr_opendf        = true,
    objbr_openlist      = false,
    objbr_place         = "script,right",
    objbr_w             = 40,
    open_example        = true,
    openhtml            = true,
    openpdf             = 2,
    paragraph_begin     = true,
    parenblock          = true,
    pdfviewer           = "undefined",
    quarto_preview_args = '',
    quarto_render_args  = '',
    rconsole_height     = 15,
    rconsole_width      = 80,
    rm_knit_cache       = false,
    rmarkdown_args      = "",
    rmd_environment     = ".GlobalEnv",
    rmdchunk            = 2, -- might be a string
    rmhidden            = false,
    rnowebchunk         = true,
    routnotab           = false,
    save_win_pos        = true,
    set_home_env        = true,
    setwidth            = 2,
    silent_term         = false,
    skim_app_path       = "",
    source_args         = "",
    specialplot         = false,
    strict_rst          = true,
    synctex             = true,
    texerr              = true,
    tmpdir              = nil,
    compldir            = nil,
    remote_compldir     = nil,
    local_R_library_dir = nil,
    user_maps_only      = false,
    wait                = 60,
    wait_reply          = 2,
}

local user_opts = {}
local did_global_setup = false

local set_editing_mode = function ()
    local em = "emacs"
    local iprc = tostring(vim.fn.expand("~/.inputrc"))
    if vim.fn.filereadable(iprc) == 1 then
        local inputrc = vim.fn.readfile(iprc)
        local line
        local e
        for _, v in pairs(inputrc) do
            line = string.gsub(v, "^%s*#.*", "")
            _, e = string.find(line, "set%s+editing%-mode")
            if e then
                em = string.gsub(line, ".+editing%-mode%s+", "")
                em = string.gsub(em, "%s*", "")
            end
        end
    end
    config.editing_mode = em
end

local set_pdf_viewer = function ()
    if vim.fn.getenv("XDG_CURRENT_DESKTOP") == "sway" then
        config.openpdf = 2
    elseif config.is_darwin or vim.fn.getenv("WAYLAND_DISPLAY") ~= "" then
        config.openpdf = 1
    else
        config.openpdf = 2
    end

    if config.is_darwin then
        config.pdfviewer = "skim"
    else
        if vim.fn.has("win32") == 1 then
            config.pdfviewer = "sumatra"
        else
            config.pdfviewer = "zathura"
        end
    end
end

local validate_user_opts = function()
    -- We don't use vim.validate() because its error message has traceback details not useful for users.
    for k, _ in pairs(user_opts) do
        if config[k] == nil then
            vim.notify("R-Nvim: unrecognized option `" .. k .. "`.", vim.log.levels.WARN)
        else
            if k == "external_term" and not (type(user_opts[k]) == "string" or type(user_opts[k]) == "boolean") then
                vim.notify("R-Nvim: option `external_term` should be either boolean or string.", vim.log.levels.WARN)
            elseif k == "rmdchunk" and not (type(user_opts[k]) == "string" or type(user_opts[k]) == "number") then
                vim.notify("R-Nvim: option `rmdchunk` should be either number or string.", vim.log.levels.WARN)
            elseif not (type(user_opts[k]) == type(config[k])) then
                vim.notify("R-Nvim: option `" .. k .. "` should be " .. type(config[k]) .. ", not " .. type(user_opts[k]) .. ".", vim.log.levels.WARN)
            end
        end
    end
end

local do_common_global = function()
    -- config.rnvim_home should be the directory where the plugin files are.
    config.rnvim_home = vim.fn.expand("<script>:h:h")

    -- config.uservimfiles must be a writable directory. It will be config.rnvim_home
    -- unless it's not writable. Then it wil be ~/.vim or ~/vimfiles.
    if vim.fn.filewritable(config.rnvim_home) == 2 then
        config.uservimfiles = config.rnvim_home
    else
        config.uservimfiles = vim.split(vim.fn.expand('&runtimepath'), ',')[1]
    end

    -- Windows logins can include domain, e.g: 'DOMAIN\Username', need to remove
    -- the backslash from this as otherwise cause file path problems.
    if vim.env.LOGNAME then
        config.user_login = vim.fn.substitute(vim.fn.escape(vim.env.LOGNAME, '\\'), '\\', '', 'g')
    elseif vim.env.USER then
        config.user_login = vim.fn.substitute(vim.fn.escape(vim.env.USER, '\\'), '\\', '', 'g')
    elseif vim.env.USERNAME then
        config.user_login = vim.fn.substitute(vim.fn.escape(vim.env.USERNAME, '\\'), '\\', '', 'g')
    elseif vim.env.HOME then
        config.user_login = vim.fn.substitute(vim.fn.escape(vim.env.HOME, '\\'), '\\', '', 'g')
    elseif vim.fn.executable('whoami') ~= 0 then
        config.user_login = vim.fn.system('whoami')
    else
        config.user_login = "NoLoginName"
        vim.fn.RWarningMsg("Could not determine user name.")
    end

    config.user_login = vim.fn.substitute(vim.fn.substitute(config.user_login, '.*\\', '', ''), '\\W', '', 'g')
    if config.user_login == "" then
        config.user_login = "NoLoginName"
        vim.fn.RWarningMsg("Could not determine user name.")
    end

    if vim.fn.has("win32") ~= 0 then
        config.rnvim_home = vim.fn.substitute(config.rnvim_home, "\\", "/", "g")
        config.uservimfiles = vim.fn.substitute(config.uservimfiles, "\\", "/", "g")
    end

    if config.compldir then
        config.compldir = vim.fn.expand(config.compldir)
    elseif vim.fn.has("win32") ~= 0 and vim.env.APPDATA then
        config.compldir = vim.fn.expand(vim.env.APPDATA) .. "\\R-Nvim"
    elseif vim.env.XDG_CACHE_HOME then
        config.compldir = vim.fn.expand(vim.env.XDG_CACHE_HOME) .. "/R-Nvim"
    elseif vim.fn.isdirectory(vim.fn.expand("~/.cache")) ~= 0 then
        config.compldir = vim.fn.expand("~/.cache/R-Nvim")
    elseif vim.fn.isdirectory(vim.fn.expand("~/Library/Caches")) ~= 0 then
        config.compldir = vim.fn.expand("~/Library/Caches/R-Nvim")
    else
        config.compldir = config.uservimfiles .. "/R/objlist/"
    end

    -- Create the directory if it doesn't exist yet
    if vim.fn.isdirectory(config.compldir) ~= 1 then
        vim.fn.mkdir(config.compldir, "p")
    end

    if vim.fn.filereadable(config.compldir .. "/uname") ~= 0 then
        config.uname = vim.fn.readfile(config.compldir .. "/uname")[1]
    else
        config.uname = vim.fn.system("uname")
        vim.fn.writefile({config.uname}, config.compldir .. "/uname")
    end
    if config.uname == "Darwin" then
        config.is_darwin = true
    end

    if config.RStudio_cmd then
        config.bracketed_paste = false
        config.parenblock = false
    end

    -- Create or update the README (omnils_ files will be regenerated if older than
    -- the README).
    local need_readme = 0
    local first_line = 'Last change in this file: 2024-01-30'
    if vim.fn.filereadable(config.compldir .. "/README") == 0 or vim.fn.readfile(config.compldir .. "/README")[1] ~= first_line then
        need_readme = 1
        vim.notify("Need README")
    end

    if need_readme == 1 then
        vim.fn.delete(config.compldir .. "/nvimcom_info")
        vim.fn.delete(config.compldir .. "/pack_descriptions")
        vim.fn.delete(config.compldir .. "/path_to_nvimcom")

        local flist = vim.fn.split(vim.fn.glob(config.compldir .. '/fun_*'), "\n")
        flist = vim.fn.extend(flist, vim.fn.split(vim.fn.glob(config.compldir .. '/omnils_*'), "\n"))
        flist = vim.fn.extend(flist, vim.fn.split(vim.fn.glob(config.compldir .. '/args_*'), "\n"))

        if #flist > 0 then
            for _, f in ipairs(flist) do
                vim.fn.delete(f)
            end
        end

        local readme = {
            first_line,
            '',
            'The files in this directory were generated by R-Nvim automatically:',
            'The omnils_ and args_ are used for omni completion, the fun_ files for ',
            'syntax highlighting, and the inst_libs for library description in the ',
            'Object Browser. If you delete them, they will be regenerated.',
            '',
            'When you load a new version of a library, their files are replaced.',
            '',
            'Files corresponding to uninstalled libraries are not automatically deleted.',
            'You should manually delete them if you want to save disk space.',
            '',
            'If you delete this README file, all omnils_, args_ and fun_ files will be ',
            'regenerated.',
            '',
            'All lines in the omnils_ files have 7 fields with information on the object',
            'separated by the byte \006:',
            '',
            '  1. Name.',
            '',
            '  2. Single character representing the Type (look at the function',
            '     nvimcom_glbnv_line at R/nvimcom/src/nvimcom.c to know the meaning of the',
            '     characters).',
            '',
            '  3. Class.',
            '',
            '  4. Either package or environment of the object.',
            '',
            '  5. If the object is a function, the list of arguments using Vim syntax for',
            '     lists (which is the same as Python syntax).',
            '',
            '  6. Short description.',
            '',
            '  7. Long description.',
            '',
            'Notes:',
            '',
            '  - There is a final \006 at the end of the line.',
            '',
            '  - All single quotes are replaced with the byte \x13.',
            '',
            '  - All \x12 will later be replaced with single quotes.',
            '',
            '  - Line breaks are indicated by \x14.',
        }

        vim.fn.writefile(readme, config.compldir .. "/README")
    end

    -- Check if the 'config' table has the key 'tmpdir'
    if not config.tmpdir then
        -- Set temporary directory based on the platform
        if vim.fn.has("win32") ~= 0 then
            if vim.fn.isdirectory(vim.env.TMP) ~= 0 then
                config.tmpdir = vim.env.TMP .. "/NvimR-" .. config.user_login
            elseif vim.fn.isdirectory(vim.env.TEMP) ~= 0 then
                config.tmpdir = vim.env.TEMP .. "/R-Nvim-" .. config.user_login
            else
                config.tmpdir = config.uservimfiles .. "/R/tmp"
            end
            config.tmpdir = vim.fn.substitute(config.tmpdir, "\\", "/", "g")
        else
            if vim.fn.isdirectory(vim.env.TMPDIR) ~= 0 then
                if vim.fn.matchstr(vim.env.TMPDIR, "/$") ~= "" then
                    config.tmpdir = vim.env.TMPDIR .. "R-Nvim-" .. config.user_login
                else
                    config.tmpdir = vim.env.TMPDIR .. "/R-Nvim-" .. config.user_login
                end
            elseif vim.fn.isdirectory("/dev/shm") ~= 0 then
                config.tmpdir = "/dev/shm/R-Nvim-" .. config.user_login
            elseif vim.fn.isdirectory("/tmp") ~= 0 then
                config.tmpdir = "/tmp/R-Nvim-" .. config.user_login
            else
                config.tmpdir = config.uservimfiles .. "/R/tmp"
            end
        end
    end

    -- Create the directory if it doesn't exist yet
    if vim.fn.isdirectory(config.tmpdir) ~= 1 then
        -- FIXME flag 0700 not working
        vim.fn.mkdir(config.tmpdir, "p")
    end

    -- Set local tmp directory when accessing R remotely
    config.localtmpdir = config.tmpdir

    -- Check if the 'config' table has the key 'remote_compldir'
    -- FIXME: replace all NVIMR_ with RNVIM_
    if config.remote_compldir then
        vim.env.NVIMR_REMOTE_COMPLDIR = config.remote_compldir
        vim.env.NVIMR_REMOTE_TMPDIR = config.remote_compldir .. '/tmp'
        config.tmpdir = config.compldir .. '/tmp'
    else
        vim.env.NVIMR_REMOTE_COMPLDIR = config.compldir
        vim.env.NVIMR_REMOTE_TMPDIR = config.tmpdir
    end

    -- Create the directory if it doesn't exist yet
    if vim.fn.isdirectory(config.localtmpdir) ~= 1 then
        -- FIXME flag 0700 not working
        vim.fn.mkdir(config.localtmpdir, "p")
    end

    vim.env.NVIMR_TMPDIR = config.tmpdir
    vim.env.NVIMR_COMPLDIR = config.compldir

    -- Default values of some variables
    if vim.fn.has('win32') ~= 0 and not (type(config.external_term) == "boolean" and config.external_term == false) then
        -- Sending multiple lines at once to Rgui on Windows does not work.
        config.parenblock = 0
    else
        config.parenblock = 1
    end

    if type(config.external_term) == "boolean" and config.external_term == false then
        config.nvimpager = 'vertical'
        config.save_win_pos = 0
        config.arrange_windows = 0
    else
        config.nvimpager = 'tab'
    end

    if vim.fn.has("win32") ~= 0 then
        config.save_win_pos = 1
        config.arrange_windows = 1
    else
        config.save_win_pos = 0
        config.arrange_windows = 0
    end

    -- The environment variables NVIMR_COMPLCB and NVIMR_COMPLInfo must be defined
    -- before starting the nvimrserver because it needs them at startup.
    config.update_glbenv = 0
    if type(package.loaded['cmp_nvim_r']) == "table" then
        config.update_glbenv = 1
    end
    vim.env.NVIMR_COMPLCB = "v:lua.require'cmp_nvim_r'.asynccb"
    vim.env.NVIMR_COMPLInfo = "v:lua.require'cmp_nvim_r'.complinfo"

    -- Look for invalid options
    local objbrplace = vim.split(config.objbr_place, ',')
    if #objbrplace > 2 then
        vim.fn.RWarningMsg('Too many options for R_objbr_place.')
    end
    for _, pos in ipairs(objbrplace) do
        if pos ~= 'console' and pos ~= 'script' and
            pos:lower() ~= 'left' and pos:lower() ~= 'right' and
            pos:lower() ~= 'above' and pos:lower() ~= 'below' and
            pos:lower() ~= 'top' and pos:lower() ~= 'bottom' then
            vim.fn.RWarningMsg('Invalid value for R_objbr_place: "' .. pos .. '". Please see R-Nvim\'s documentation.')
        end
    end

    -- Check if default mean of communication with R is OK

    -- Minimum width for the Object Browser
    if config.objbr_w < 10 then
        config.objbr_w = 10
    end

    -- Minimum height for the Object Browser
    if config.objbr_h < 4 then
        config.objbr_h = 4
    end

    vim.cmd("autocmd BufEnter * lua require('r.edit').buf_enter()")
    if vim.bo.filetype ~= "rbrowser" then
        vim.cmd("autocmd VimLeave * lua require('r.edit').vim_leave()")
    end

    if vim.v.windowid ~= 0 and vim.env.WINDOWID == "" then
        vim.env.WINDOWID = vim.v.windowid
    end

    -- Current view of the object browser: .GlobalEnv X loaded libraries
    config.curview = "None"

    -- SyncTeX options
    config.has_wmctrl = 0
    config.has_awbt = 0

    -- Set the name of R executable
    if vim.fn.has("win32") == 1 then
        if type(config.external_term) == "boolean" and config.external_term == false then
            config.R_app = "Rterm.exe"
        else
            config.R_app = "Rgui.exe"
        end
        config.R_cmd = "R.exe"
    else
        config.R_app = "R"
        config.R_cmd = "R"
    end

    -- Set security variables
    if not vim.fn.has("nvim-0.7.0") then
        vim.env.NVIMR_ID = vim.fn.substitute(tostring(vim.fn.reltimefloat(vim.fn.reltime())), '.*\\.', '', '')
        vim.env.NVIMR_SECRET = vim.fn.substitute(tostring(vim.fn.reltimefloat(vim.fn.reltime())), '.*\\.', '', '')
    else
        vim.env.NVIMR_ID = vim.fn.rand(vim.fn.srand())
        vim.env.NVIMR_SECRET = vim.fn.rand()
    end

    -- Avoid problems if either R_rconsole_width or R_rconsole_height is a float number
    -- (https://github.com/jalvesaq/Nvim-R/issues/751#issuecomment-1742784447).
    if type(config.rconsole_width) == "number" then
        config.rconsole_width = vim.fn.float2nr(config.rconsole_width)
    end
    if type(config.rconsole_height) == "number" then
        config.rconsole_height = vim.fn.float2nr(config.rconsole_height)
    end
end

local windows_config = function ()
    local isi386 = false
    local rinstallpath = nil

    if config.R_path then
        local rpath = vim.fn.split(config.R_path, ';')
        vim.fn.map(rpath, 'expand(v:val)')
        vim.fn.reverse(rpath)
        for _, dir in ipairs(rpath) do
            if vim.fn.isdirectory(dir) then
                vim.fn.system('set PATH=' .. dir .. ';' .. vim.fn.getenv('PATH'))
            else
                vim.fn.RWarningMsg('"' .. dir .. '" is not a directory. Fix the value of R_path in your vimrc.')
            end
        end
    else
        local RT40home = vim.env.RTOOLS40_HOME
        if vim.fn.isdirectory(RT40home .. '\\usr\\bin') then
            vim.fn.system('set PATH=' .. RT40home .. '\\usr\\bin;' .. vim.fn.getenv('PATH'))
        elseif vim.fn.isdirectory('C:\\rtools40\\usr\\bin') then
            vim.fn.system('set PATH=C:\\rtools40\\usr\\bin;' .. vim.fn.getenv('PATH'))
        end
        if vim.fn.isdirectory(RT40home .. '\\mingw64\\bin\\') then
            vim.fn.system('set PATH=' .. RT40home .. '\\mingw64\\bin;' .. vim.fn.getenv('PATH'))
        elseif vim.fn.isdirectory('C:\\rtools40\\mingw64\\bin') then
            vim.fn.system('set PATH=C:\\rtools40\\mingw64\\bin;' .. vim.fn.getenv('PATH'))
        end

        local run_cmd_content = {'reg.exe QUERY "HKLM\\SOFTWARE\\R-core\\R" /s'}
        vim.fn.writefile(run_cmd_content, config.tmpdir .. "/run_cmd.bat")
        local ripl = vim.fn.system(config.tmpdir .. "/run_cmd.bat")
        local rip = vim.fn.filter(vim.fn.split(ripl, "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
        if #rip == 0 then
            -- Normally, 32 bit applications access only 32 bit registry and...
            -- We have to try again if the user has installed R only in the other architecture.
            local reg_cmd = (vim.fn.has("win64") and 'reg.exe QUERY "HKLM\\SOFTWARE\\R-core\\R" /s /reg:32' or 'reg.exe QUERY "HKLM\\SOFTWARE\\R-core\\R" /s /reg:64')
            vim.fn.writefile({reg_cmd}, config.tmpdir .. "/run_cmd.bat")
            ripl = vim.fn.system(config.tmpdir .. "/run_cmd.bat")
            rip = vim.fn.filter(vim.fn.split(ripl, "\n"), 'v:val =~ ".*InstallPath.*REG_SZ"')
        end
        if #rip > 0 then
            rinstallpath = vim.fn.substitute(rip[1], '.*InstallPath.*REG_SZ\\s*', '', '')
            rinstallpath = vim.fn.substitute(rinstallpath, '\\n', '', 'g')
            rinstallpath = vim.fn.substitute(rinstallpath, '\\s*$', '', 'g')
        end
        if not vim.fn.exists("rinstallpath") then
            vim.fn.RWarningMsg("Could not find R path in Windows Registry. If you have already installed R, please, set the value of 'R_path'.")
            return
        end
        local hasR32 = vim.fn.isdirectory(rinstallpath .. '\\bin\\i386')
        local hasR64 = vim.fn.isdirectory(rinstallpath .. '\\bin\\x64')
        if hasR32 == 1 and not hasR64 then
            isi386 = true
        end
        if hasR64 == 1 and not hasR32 then
            isi386 = false
        end
        if hasR32 == 1 and isi386 then
            vim.fn.system('set PATH=' .. rinstallpath .. '\\bin\\i386;' .. vim.fn.getenv('PATH'))
        elseif hasR64 and isi386 == 0 then
            vim.fn.system('set PATH=' .. rinstallpath .. '\\bin\\x64;' .. vim.fn.getenv('PATH'))
        else
            vim.fn.system('set PATH=' .. rinstallpath .. '\\bin;' .. vim.fn.getenv('PATH'))
        end
    end

    if not config.R_args then
        if type(config.external_term) == "boolean" and config.external_term == false then
            config.R_args = {"--no-save"}
        else
            config.R_args = {"--sdi", "--no-save"}
        end
    end
end

local tmux_config = function ()
    -- Check whether Tmux is OK
    if vim.fn.executable('tmux') == 0 then
        config.external_term = 0
        vim.fn.RWarningMsg("tmux executable not found")
        return
    end

    local tmuxversion
    if config.uname:find("OpenBSD") then
        -- Tmux does not have -V option on OpenBSD: https://github.com/jcfaria/Vim-R-plugin/issues/200
        tmuxversion = "0.0"
    else
        tmuxversion = vim.fn.system("tmux -V")
        tmuxversion = vim.fn.substitute(tmuxversion, '.* \\([0-9]\\.[0-9]\\).*', '\\1', '')
        if vim.fn.strlen(tmuxversion) ~= 3 then
            tmuxversion = "1.0"
        end
        if tmuxversion < "3.0" then
            vim.fn.RWarningMsg("R-Nvim requires Tmux >= 3.0")
        end
    end
end

local unix_config = function ()
    if config.R_path then
        local rpath = vim.fn.split(config.R_path, ':')
        vim.fn.map(rpath, 'expand(v:val)')
        table.insert(rpath, 1, '')
        for _, dir in ipairs(vim.fn.reverse(rpath)) do
            if vim.fn.isdirectory(dir) == 1 then
                vim.env.PATH = dir .. ':' .. vim.env.PATH
            else
                vim.fn.RWarningMsg('"' .. dir .. '" is not a directory. Fix the value of R_path in your config.')
            end
        end
    end

    if vim.fn.executable(config.R_app) == 0 then
        vim.fn.RWarningMsg('"' .. config.R_app .. '" not found. Fix the value of either R_path or R_app in your config.')
    end

    if (type(config.external_term) == "boolean" and config.external_term) or type(config.external_term) == "string" then
        tmux_config()
    end
end

local global_setup = function ()
    did_global_setup = true

    validate_user_opts()

    -- Override default config values with user options for the first time.
    -- Some config options depend on others to have their default values set.
    for k, v in pairs(user_opts) do
        config[k] = v
    end

    -- Config values that depend on either system features or other config
    -- values.
    set_editing_mode()

    -- Load functions that were not converted to Lua yet
    -- Configure more values that depend on either system features or other
    -- config values.
    -- Fix some invalid values
    vim.cmd.runtime("R/common_global.vim")
    do_common_global()
    if vim.fn.has("win32") == 1 then
        windows_config()
    else
        unix_config()
    end
    set_pdf_viewer()

    -- Override default config values with user options for the second time.
    for k, v in pairs(user_opts) do
        config[k] = v
    end

    vim.cmd("autocmd VimEnter * lua require('r.config').check_health()")

    vim.fn.timer_start(1, function ()
        require("r.nrs").check_nvimcom_version()
    end)
    -- The calls to system() and executable() below are in this script to run
    -- asynchronously and avoid slow startup on macOS.
    -- See https://github.com/jalvesaq/Nvim-R/issues/625
end

M = {}

--- Store user options
---@param opts table User options
M.store_user_opts = function(opts)
    -- Keep track of R-Nvim status:
    -- 0: ftplugin/* not sourced yet.
    -- 1: ftplugin/* sourced, but nclientserver not started yet.
    -- 2: nclientserver started, but not ready yet.
    -- 3: nclientserver is ready.
    -- 4: R started, but nvimcom was not loaded yet.
    -- 5: nvimcom is loaded.
    vim.g.R_Nvim_status = 0

    user_opts = opts
end

--- Real setup function.
--- Set initial values of some internal variables.
--- Set the default value of config variables that depend on system features.
M.real_setup = function ()
    vim.g.R_Nvim_status = 1

    -- Check if b:pdf_is_open already exists to avoid errors at other places
    if vim.fn.exists("b:pdf_is_open")  == 0 then
        vim.api.nvim_buf_set_var(0, "pdf_is_open", false)
    end

    if not did_global_setup then
        global_setup()
    end
end

--- Return the table with the final configure variables: the default values
--- overridden by user options.
---@return table
M.get_config = function ()
    return config
end

M.check_health = function ()
    -- Check if Vim-R-plugin is installed
    if vim.fn.exists("*WaitVimComStart") ~= 0 then
        vim.notify("Please, uninstall Vim-R-plugin before using R-Nvim.", vim.log.levels.ERROR)
    end

    -- Check if Nvim-R is installed
    -- FIXME: choose a function that exists in Nvim-R, but not in R-Nvim
    if vim.fn.exists("*WaitVimComStart") ~= 0 then
        vim.notify("Please, uninstall Nvim-R before using R-Nvim.", vim.log.levels.ERROR)
    end

    if vim.fn.executable(config.R_app) == 0 then
        vim.fn.RWarningMsg("R_app executable not found: '" .. config.R_app .. "'")
    end

    if not config.R_cmd == config.R_app and vim.fn.executable(config.R_cmd) == 0 then
        vim.fn.RWarningMsg("R_cmd executable not found: '" .. config.R_cmd .. "'")
    end
end

return M