local A = vim.api

local U = {}

---Comment modes
---@class CMode
U.cmode = {
    toggle = 0,
    comment = 1,
    uncomment = 2,
}

---Comment types
---@class CType
U.ctype = {
    line = 1,
    block = 2,
}

---Motion types
---@class CMotion
U.cmotion = {
    ---Compute from vmode
    _ = 0,
    ---line
    line = 1,
    ---char/left-right
    char = 2,
    ---visual line
    block = 3,
    ---visual
    v = 4,
}

---Print a msg on stderr
---@param msg string
function U.errprint(msg)
    vim.notify('Comment.nvim: ' .. msg, vim.log.levels.ERROR)
end

---Check whether the line is empty
---@param ln string
---@return boolean
function U.is_empty(ln)
    return ln:find('^$') ~= nil
end

---Replace some char in the give string
---@param pos number Position for the replacement
---@param str string String that needs to be modified
---@param rep string Replacement chars
---@return string string Replaced string
function U.replace(pos, str, rep)
    return str:sub(0, pos) .. rep .. str:sub(pos + 1)
end

---Trim leading/trailing whitespace from the given string
---@param str string
---@return string
function U.trim(str)
    return str:match('^%s?(.-)%s?$')
end

---Get region for vim mode
---@param vmode string VIM mode
---@return number number start column
---@return number number end column
---@return number number start row
---@return number number end row
function U.get_region(vmode)
    local m = A.nvim_buf_get_mark
    local buf = 0
    local sln, eln

    if vmode:match('[vV]') then
        sln = m(buf, '<')
        eln = m(buf, '>')
    else
        sln = m(buf, '[')
        eln = m(buf, ']')
    end

    return sln[1], eln[1], sln[2], eln[2]
end

---Get lines from a NORMAL/VISUAL mode
---@param vmode string VIM mode
---@param ctype CType Comment string type
---@return number number Start index of the lines
---@return number number End index of the lines
---@return table table List of lines inside the start and end index
---@return number number Start row
---@return number number End row
function U.get_lines(vmode, ctype)
    local scol, ecol, srow, erow = U.get_region(vmode)

    local sln = scol - 1

    -- If start and end is same, then just return the current line
    local lines
    if scol == ecol then
        lines = { A.nvim_get_current_line() }
    elseif ctype == U.ctype.block then
        -- In block we only need the starting and endling line
        lines = {
            A.nvim_buf_get_lines(0, sln, scol, false)[1],
            A.nvim_buf_get_lines(0, ecol - 1, ecol, false)[1],
        }
    else
        -- decrementing `scol` by one bcz marks are 1 based but lines are 0 based
        lines = A.nvim_buf_get_lines(0, sln, ecol, false)
    end

    return sln, ecol, lines, srow, erow
end

---Converts the given string into a commented string
---@param ln string String that needs to be commented
---@param lcs string Left side of the commentstring
---@param rcs string Right side of the commentstring
---@param is_pad boolean Whether to add padding b/w comment and line
---@param spacing string|nil Pre-determine indentation (useful) when dealing w/ multiple lines
---@return string string Commented string
function U.comment_str(ln, lcs, rcs, is_pad, spacing)
    if U.is_empty(ln) then
        -- FIXME on block comment this won't comment the last line if it is empty
        return (spacing or '') .. lcs
    end

    local indent, chars = ln:match('^(%s*)(.*)')

    if is_pad then
        local lcs_new = #lcs > 0 and lcs .. ' ' or lcs
        local rcs_new = #rcs > 0 and ' ' .. rcs or rcs
        return U.replace(#(spacing or indent), indent, lcs_new) .. chars .. rcs_new
    end

    return U.replace(#(spacing or indent), indent, lcs) .. chars .. rcs
end

---Converts the given string into a uncommented string
---@param ln string Line that needs to be uncommented
---@param lcs_esc string (Escaped) Left side of the commentstring
---@param rcs_esc string (Escaped) Right side of the commentstring
---@param is_pad boolean Whether to add padding b/w comment and line
---@return string string Uncommented string
function U.uncomment_str(ln, lcs_esc, rcs_esc, is_pad)
    if not U.is_commented(ln, lcs_esc) then
        return ln
    end

    -- TODO improve lhs cstr and rhs cstr detection
    local indent, chars = ln:match('(%s*)' .. lcs_esc .. '%s?(.*)' .. rcs_esc .. '$?')

    -- If the line (after cstring) is empty then just return ''
    -- bcz when uncommenting multiline this also doesn't preserve leading whitespace as the line was previously empty
    if #chars == 0 then
        return ''
    end

    -- When padding is enabled then trim one trailing space char
    return indent .. (is_pad and chars:gsub('%s?$', '') or chars)
end

---Call a function if exists
---@param fn function Hook function
---@return boolean|string
function U.is_fn(fn, ...)
    return type(fn) == 'function' and fn(...)
end

---Check if the given string is commented or not
---@param ln string Line that needs to be checked
---@param lcs_esc string (Escaped) Left side of the commentstring
---@return number
function U.is_commented(ln, lcs_esc)
    return ln:find('^%s*' .. lcs_esc)
end

---Check if the given line is ignored or not with the given pattern
---@param ln string Line to be ignored
---@param pat string Lua regex
---@return boolean
function U.ignore(ln, pat)
    return pat and ln:find(pat) ~= nil
end

---Check if the given string is block commented or not
---@param ln string Line that needs to be checked
---@param lcs_esc string (Escaped) Left side of the commentstring
---@param rcs_esc string (Escaped) Right side of the commentstring
---@return string
function U.is_block_commented(ln, lcs_esc, rcs_esc)
    return ln:match('^' .. lcs_esc .. '%s?(.-)%s?' .. rcs_esc .. '$')
end

return U
