-- Reference pattern parser: extracts file references from text lines.
-- Returns { path, from?, to? }, start, end (0-based byte offsets) or nil.

local M = {}

-- Try to match a reference pattern (path, path#L10, path#L10-L20) against a
-- string.  `resolve(path)` must return a truthy value for the path to be
-- accepted.  Returns { path, from?, to? } or nil.
function M.try_match_ref(s, resolve)
  local path, from, to = s:match("^(%S+)#L(%d+)%-L(%d+)$")
  if path and resolve(path) then
    return { path = path, from = tonumber(from), to = tonumber(to) }
  end

  path, from = s:match("^(%S+)#L(%d+)$")
  if path and resolve(path) then
    return { path = path, from = tonumber(from) }
  end

  -- whole-file reference: a lone token with an extension that resolves to a real file
  if s:match("^%S+$") and s:match("%.[%w]+$") and resolve(s) then
    return { path = s }
  end

  return nil
end

-- Search `line` for a reference pattern (optionally wrapped in backticks or
-- markdown link syntax).  `resolve(path)` must return a truthy value for the
-- path to be accepted.  Returns { path, from?, to? }, start, end where
-- start/end are 0-based byte offsets of the reference *content* (excluding
-- wrappers) in the trimmed line, or nil.
function M.parse_ref(line, resolve)
  local s = vim.trim(line)

  -- 1. backtick-wrapped range: `path#L10-L20`
  local pos = s:find("`[^`]*#L%d+%-L%d+[^`]*`")
  if pos then
    local content = s:match("`([^`]*#L%d+%-L%d+[^`]*)`", pos)
    if content then
      local ref = M.try_match_ref(content, resolve)
      if ref then
        return ref, pos, pos + #content - 1
      end
    end
  end

  -- 2. markdown link range: [...](path#L10-L20)
  do
    local i = s:find("%[")
    while i do
      local j = s:find("%]%(", i + 1)
      if j then
        local k = s:find("%)", j + 2)
        if k then
          local target = s:sub(j + 2, k - 1)
          local ref = M.try_match_ref(target, resolve)
          if ref and ref.from then
            return ref, j + 1, k - 2
          end
        end
      end
      i = s:find("%[", i + 1)
    end
  end

  -- 3. bare range: path#L10-L20
  pos = s:find("%S+#L%d+%-L%d+")
  if pos then
    local raw = s:match("(%S+#L%d+%-L%d+)", pos)
    if raw then
      local ref = M.try_match_ref(raw, resolve)
      if ref then
        return ref, pos - 1, pos + #raw - 2
      end
    end
  end

  -- 4. backtick-wrapped single line: `path#L10`
  pos = s:find("`[^`]*#L%d+[^`]*`")
  if pos then
    local content = s:match("`([^`]*#L%d+[^`]*)`", pos)
    if content then
      local ref = M.try_match_ref(content, resolve)
      if ref then
        return ref, pos, pos + #content - 1
      end
    end
  end

  -- 5. markdown link single line: [...](path#L10)
  do
    local i = s:find("%[")
    while i do
      local j = s:find("%]%(", i + 1)
      if j then
        local k = s:find("%)", j + 2)
        if k then
          local target = s:sub(j + 2, k - 1)
          local ref = M.try_match_ref(target, resolve)
          if ref and ref.from then
            return ref, j + 1, k - 2
          end
        end
      end
      i = s:find("%[", i + 1)
    end
  end

  -- 6. bare single line: path#L10
  pos = s:find("%S+#L%d+")
  if pos then
    local raw = s:match("(%S+#L%d+)", pos)
    if raw then
      local ref = M.try_match_ref(raw, resolve)
      if ref then
        return ref, pos - 1, pos + #raw - 2
      end
    end
  end

  -- 7. backtick-wrapped whole file: `path`
  pos = s:find("`[^`]+`")
  if pos then
    local content = s:match("`([^`]+)`", pos)
    if content then
      local ref = M.try_match_ref(content, resolve)
      if ref then
        return ref, pos, pos + #content - 1
      end
    end
  end

  -- 8. markdown link whole file: [label](path)
  do
    local i = s:find("%[")
    while i do
      local j = s:find("%]%(", i + 1)
      if j then
        local k = s:find("%)", j + 2)
        if k then
          local target = s:sub(j + 2, k - 1)
          local ref = M.try_match_ref(target, resolve)
          if ref then
            return ref, j + 1, k - 2
          end
        end
      end
      i = s:find("%[", i + 1)
    end
  end

  -- 9. bare whole file (path without #L)
  pos = s:find("[%w%-%./]+")
  if pos then
    local raw = s:match("([%w%-%./]+)", pos)
    if raw then
      local ref = M.try_match_ref(raw, resolve)
      if ref then
        return ref, pos - 1, pos + #raw - 2
      end
    end
  end

  return nil
end

return M
