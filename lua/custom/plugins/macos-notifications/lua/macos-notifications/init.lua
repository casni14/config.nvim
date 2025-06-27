-- ~/.config/nvim/lua/custom/plugins/macos-notifications/lua/init.lua
--
-- Cross-version Notification Center reader (macOS 10.8 → 26)
-- -----------------------------------------------------------

local M, api = {}, vim.api

-- small logger -------------------------------------------------------------
local function log(msg, lvl)
  vim.notify('[macos-notifications] ' .. tostring(msg), lvl or vim.log.levels.DEBUG)
end

-- turn "net.whatsapp.WhatsApp" → "WhatsApp", "com.apple.iCal" → "iCal"
local function app_name(bundle)
  if not bundle then
    return '—'
  end
  return bundle:match '([^%.]+)$' or bundle -- chars that are *not* a dot, to EOL
end

local function load_seen()
  local ok, txt = pcall(vim.fn.readfile, state_file)
  if not ok then
    return {}
  end
  local ok2, decoded = pcall(vim.fn.json_decode, table.concat(txt, '\n'))
  return ok2 and decoded or {}
end

local function save_seen(seen)
  vim.fn.writefile({ vim.fn.json_encode(seen) }, state_file)
end

-- ~/.config/nvim/lua/custom/plugins/macos-notifications/lua/init.lua
local state_file = vim.fn.stdpath 'state' .. '/macos-notifications-seen.json'

-- locate the SQLite DB on any macOS release -------------------------------
local function find_db()
  -- Sequoia / macOS 25-26
  local gc = vim.fn.expand '~/Library/Group Containers/group.com.apple.usernoted/db2/db'
  if vim.fn.filereadable(gc) == 1 then
    return gc
  end

  -- Catalina → Sonoma
  local du = (vim.fn.system('getconf DARWIN_USER_DIR'):gsub('%s+$', '')) .. '/com.apple.notificationcenter/db2/db'
  if vim.fn.filereadable(du) == 1 then
    return du
  end

  -- Mountain-Lion → Mojave
  local old = vim.fn.globpath(vim.fn.expand '~/Library/Application Support/NotificationCenter', '*.db', false, true)[1]
  if old and #old > 0 then
    return old
  end
  return nil
end

-- decode hex-encoded NSKeyedArchiver blob → Lua table ----------------------
local function decode_blob(hex)
  -- 1. hex → tmp_hex
  local tmp_hex = vim.fn.tempname()
  vim.fn.writefile({ hex }, tmp_hex)

  -- 2. tmp_hex → tmp_bin (xxd writes directly to file → no NUL problems)
  local tmp_bin = vim.fn.tempname()
  vim.fn.system { 'xxd', '-r', '-p', tmp_hex, tmp_bin }
  vim.fn.delete(tmp_hex)

  ------------------------------------------------------------------------
  -- Instead of JSON, ask plutil for a readable dictionary (-p) and tell
  -- it to unarchive the keyed-archive first (-r).
  ------------------------------------------------------------------------
  local txt = vim.fn.system { 'plutil', '-p', '-r', tmp_bin }
  vim.fn.delete(tmp_bin)

  ------------------------------------------------------------------------
  -- The output now looks like:
  --
  -- { "req" => { "titl" => "Mail", "body" => "New message" }, … }
  --
  -- Simple patterns are enough to extract title/body.
  ------------------------------------------------------------------------

  local title = txt:match '"titl"%s*=>%s*"([^"]-)"' or txt:match '"title"%s*=>%s*"([^"]-)"' -- fallback key
  local body = txt:match '"body"%s*=>%s*"([^"]-)"' or ''
  local app = txt:match '"app"%s*=>%s*"([^"]-)"' or ''

  return { req = { titl = title, body = body }, app = app }
end

-- choose SQL for new vs. legacy schema ------------------------------------
local function build_sql(db, limit)
  if os.execute(('sqlite3 %q "SELECT 1 FROM record LIMIT 1;" >/dev/null 2>&1'):format(db)) == 0 then
    return ([[SELECT delivered_date, hex(data) FROM record
              ORDER  BY delivered_date DESC LIMIT %d;]]):format(limit)
  end
  return ([[SELECT date, hex(message) FROM notifications
            ORDER  BY date DESC LIMIT %d;]]):format(limit)
end

-- read + parse notifications ----------------------------------------------
local function get_notifications(limit)
  limit = limit or 15
  local db = find_db()
  if not db then
    vim.notify('Notification DB not found – grant Terminal Full Disk Access', vim.log.levels.WARN)
    return {}
  end

  local sql = build_sql(db, limit)
  local raw = vim.fn.system(('sqlite3 -noheader -separator "|" %q %q'):format(db, sql))
  if vim.v.shell_error ~= 0 then
    log('sqlite3 exit ' .. vim.v.shell_error, vim.log.levels.WARN)
    return {}
  end

  local out = {}
  for ts, hex in raw:gmatch '([%d%.]+)|([0-9A-Fa-f]+)' do
    local plist = decode_blob(hex)
    local alert = plist.req or plist.alert or {}
    local app = app_name(plist.app)

    -- CFAbsoluteTime → Unix epoch if needed
    local epoch = tonumber(ts)
    if epoch and epoch < 978307200 then
      epoch = epoch + 978307200
    end

    local time_str = os.date('%Y-%m-%d %H:%M:%S', math.floor(epoch or 0))
    local title = alert.titl or alert.title or plist.app or '—'
    local key = ('%s|%s|%s'):format(time_str, app, title)

    table.insert(out, {
      time = os.date('%Y-%m-%d %H:%M:%S', math.floor(epoch or 0)),
      title = alert.titl or alert.title or plist.app or '—',
      body = alert.body or '',
      app = app,
      key = key,
    })
  end
  return out
end

local app_blacklist = { 'wwdc-Release', 'RadioFrance', 'AppStore' }

local function array_includes(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

-- floating-window UI -------------------------------------------------------
local function show_notifications()
  local notes = get_notifications(15)
  if #notes == 0 then
    vim.notify('No recent notifications found', vim.log.levels.INFO)
    return
  end

  local buf, lines = api.nvim_create_buf(false, true), {}
  local seen = load_seen() -- JSON → Lua set
  local newest = {} -- keys we are about to record
  local hl = {} -- {line_nr = true}

  for _, n in ipairs(notes) do
    if array_includes(app_blacklist, n.app) then
      goto continue
    end

    local is_new = not seen[n.key]
    if is_new then
      hl[#lines + 1] = true
    end -- highlight this line
    newest[n.key] = true

    table.insert(lines, ('[%s] (%s) %s'):format(n.time, n.app, n.title))
    for _, line in ipairs(vim.split(n.body or '', '\n')) do
      table.insert(lines, '    ' .. line)
    end
    table.insert(lines, '')

    ::continue::
  end
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  -- define a highlight (once per session)
  vim.cmd 'hi default link MacNoteNew Title'

  -- apply it to the stored line numbers
  for lnr, _ in pairs(hl) do
    api.nvim_buf_add_highlight(buf, -1, 'MacNoteNew', lnr - 1, 0, -1)
  end

  local W = vim.o.columns
  local H = vim.o.lines
  local width = math.min(math.floor(W * 0.4), 120)
  local height = math.min(vim.o.lines, math.floor(H * 0.8))

  -- top-right corner:
  local row = 0
  local col = W - width

  api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    width = width,
    height = height,
    row = row,
    col = col,
  })
  ------------------------------------------------------------------------
  -- Press “q” in normal mode to close the floating window.
  ------------------------------------------------------------------------
  api.nvim_buf_set_keymap(buf, 'n', 'q', '<cmd>close<CR>', { silent = true, nowait = true, noremap = true })
  ---------------------------------------------------------------------------
  -- merge:  seen ← seen ∪ newest
  ---------------------------------------------------------------------------
  for k in pairs(newest) do
    seen[k] = true -- add every key we just displayed
  end
  save_seen(seen) -- persist the enlarged set
end
-- public setup -------------------------------------------------------------
function M.setup()
  api.nvim_create_user_command('MacNotifications', show_notifications, {})
end

return M
