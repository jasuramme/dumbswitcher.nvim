local switcher = require("dumbswitcher")

vim.api.nvim_create_user_command("DumbSwitcher", function(opts)
    switcher.switch_source_header(opts.args == "grep")
end, { nargs = "?" })
