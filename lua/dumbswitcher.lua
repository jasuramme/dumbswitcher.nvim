local M = {}

local default_settings = {
    source_exts = { "c", "cpp", "cxx", "cc" },
    source_dir = { "src" },
    header_exts = { "h", "hpp", "hxx" },
    header_dir = { "inc" },
    absolute_dir = false,
    root = nil,
    verbose = false
}

local _SH = {}

local function _log(str)
    if _SH.verbose then
        print(str)
    end
end

M.setup = function(opts)
    _SH = vim.tbl_extend("force", default_settings, opts or {})
end

M.is_source = function(filename)
    local fileext = vim.fn.fnamemodify(filename, ":e")
    if vim.tbl_contains(_SH.source_exts, fileext) then
        return true
    end
    return false
end

M.is_header = function(filename)
    local fileext = vim.fn.fnamemodify(filename, ":e")
    if vim.tbl_contains(_SH.header_exts, fileext) then
        return true
    end
    return false
end

local function get_root()
    if _G.PROJECT_ROOT and _G.PROJECT_ROOT ~= "" then
        return _G.PROJECT_ROOT
    end
    local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1] or ""
    if git_root ~= "" then
        return git_root
    end
    return vim.fn.getcwd()
end


local function up_a_dir(dir, path_after)
    local parent = vim.fn.fnamemodify(dir, ":h")

    if parent == dir or parent == "" then
        return nil, path_after
    end

    local new_path_after = vim.fn.fnamemodify(dir, ":t")
    if path_after ~= "" then
        new_path_after = new_path_after .. "/" .. path_after
    end

    return parent, new_path_after
end


local function file_exists(path)
    _log('Check file exists ' .. path)
    local f = io.open(path, "r")
	if f then
		f:close()
		return true
	else
		return false
	end
end

local function search_files_in_dir(dir, filename, extensions)
    if dir:sub(-1) == "/" then
        dir = dir:sub(1, -2)
    end
    _log('looking for ' .. filename .. ' in ' .. dir)
    for _, ext in ipairs(extensions) do
        local file = dir .. "/" .. filename .. "." .. ext
        if file_exists(file) then
            return file
        end
    end
    return nil
end

local function find_file(path, extensions, search_dirs, use_grep)
    _log('Lookup file ' .. vim.inspect(path))
    _log('extensions ' .. vim.inspect(extensions))
    _log('search_dirs ' .. vim.inspect(search_dirs))
    local filename = vim.fn.fnamemodify(path, ":t:r")
    local dir_before = vim.fn.fnamemodify(path, ":h")
    local dir_after = ''
    local ret = search_files_in_dir(dir_before, filename, extensions)
    if ret then return ret end

    while dir_before do
        for _, search_dir in ipairs(search_dirs) do
            local iter_dir
            if _SH.absolute_dir == true then
                iter_dir = search_dir
            else
                iter_dir = dir_before .. "/" .. search_dir
            end
            _log('looking for ' .. iter_dir)
            if file_exists(iter_dir) then
                _log('found ' .. iter_dir)
                local after = dir_after
                local dir_to_search = ''
                while after do
                    ret = search_files_in_dir(iter_dir .. '/' .. dir_to_search, filename, extensions)
                    if ret then return ret end
                    after, dir_to_search = up_a_dir(after, dir_to_search)
                end
            end
        end
        dir_before, dir_after = up_a_dir(dir_before, dir_after)
    end
    if use_grep then
        local root
        if _SH.root then
            root = _SH.root
        else
            root = get_root()
        end
        for _, ext in ipairs(extensions) do
            local pattern = root .. "/**/" .. filename .. "." .. ext
            local matches = vim.fn.glob(pattern, true, true) -- флаг true возвращает список путей
            if #matches > 0 then
                return matches[1]
            end
        end
    end
    return nil
end

M._get_switch_file = function(use_grep)
    local current_file = vim.api.nvim_buf_get_name(0)
    local extensions = {}
    local search_dirs = {}
    if M.is_source(current_file) then
        extensions = _SH.header_exts
        search_dirs = _SH.header_dir
    elseif M.is_header(current_file) then
        extensions = _SH.source_exts
        search_dirs = _SH.source_dir
    else
        return nil
    end
    return find_file(current_file, extensions, search_dirs, use_grep)
end

M.switch_source_header = function(use_grep)
    local ret = M._get_switch_file(use_grep)
    if ret then
        vim.cmd("edit " .. ret)
    else
        print("File not found.")
    end
end

local seen_files = {}

M.peek_into_src = function()
    local current_file = vim.api.nvim_buf_get_name(0)
    if seen_files[current_file] then return end
    seen_files[current_file] = true
    if M.is_header(current_file) then
        local src_file = find_file(current_file, _SH.source_exts, _SH.source_dir, false)
        if not src_file then return end

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
        vim.api.nvim_buf_set_name(buf, src_file)

        vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent! edit " .. vim.fn.fnameescape(src_file))
        end)
    end
end

return M
