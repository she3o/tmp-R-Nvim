local M = {}
local job = require("r.job")
local warn = require("r").warn
local config = require("r.config").get_config()

local on_okular_stdout = function (_, data, _)
    for _, cmd in ipairs(data) do
        if vim.startswith(cmd, "call ") then
            vim.cmd(cmd)
        end
    end
end

M.open = function (fullpath)
    job.start("OkularSyncTeX", {
            "okular",
            "--unique",
            "--editor-cmd",
            "echo 'call SyncTeX_backward(\"%f\", \"%l\")'",
            fullpath
        },
        {
            detach = true,
            on_stdout = on_okular_stdout,
        }
    )
    if job.is_running("Okular") < 1 then
        warn("Failed to run Okular...")
    end
end

M.SyncTeX_forward = function (tpath, ppath, texln, _)
    local texname = vim.fn.substitute(tpath, ' ', '\\ ', 'g')
    local pdfname = vim.fn.substitute(ppath, ' ', '\\ ', 'g')
    job.start("OkularSyncTeX",
        {
            "okular",
            "--unique",
            "--editor-cmd",
            "echo 'call SyncTeX_backward(\"%f\", \"%l\")'",
            pdfname .. "#src:" .. texln .. texname
        },
        {
            detach = true,
            on_stdout = on_okular_stdout,
        }
    )
    if job.is_running("OkularSyncTeX") < 1 then
        warn("Failed to run Okular (SyncTeX forward)...")
    end
    if config.has_awbt then
        require("r.edit").raise_window(pdfname)
    end
end

return M