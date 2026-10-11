local M = {}

-- Cached JDK resolution: false = resolved and not found, nil = not resolved yet.
local jdk_home = nil
local warned_no_jdk = false

local function is_jdk_home(path)
  return path and path ~= "" and vim.fn.executable(path .. "/bin/java") == 1
end

local function run(cmd)
  local ok, res = pcall(vim.system, cmd, { text = true })
  if not ok then
    return nil
  end
  local out = res:wait()
  if out.code ~= 0 then
    return nil
  end
  return vim.trim(out.stdout or "")
end

local function resolve_jdk()
  if jdk_home ~= nil then
    return jdk_home or nil
  end

  local env = vim.env.JAVA_HOME
  if is_jdk_home(env) then
    jdk_home = env
    return jdk_home
  end

  if vim.fn.executable("/usr/libexec/java_home") == 1 then
    local out = run({ "/usr/libexec/java_home" })
    if is_jdk_home(out) then
      jdk_home = out
      return jdk_home
    end
  end

  for _, p in ipairs({
    "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home",
    "/usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home",
  }) do
    if is_jdk_home(p) then
      jdk_home = p
      return jdk_home
    end
  end

  -- PATH java, only if it actually works (macOS ships a non-functional stub).
  local java = vim.fn.exepath("java")
  if java ~= "" and run({ java, "-version" }) ~= nil then
    local real = vim.uv.fs_realpath(java) or java
    local home = vim.fn.fnamemodify(real, ":h:h")
    jdk_home = is_jdk_home(home) and home or ""
    if jdk_home ~= "" then
      return jdk_home
    end
  end

  jdk_home = false
  return nil
end

function M.start()
  local ok, jdtls = pcall(require, "jdtls")
  if not ok then
    vim.notify("nvim-jdtls is not installed yet. Run :Lazy sync", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local root_dir = vim.fs.root(bufnr, {
    { "mvnw", "gradlew", "settings.gradle", "settings.gradle.kts", "pom.xml", "build.gradle", "build.gradle.kts" },
    ".git",
  })
  if not root_dir then
    return
  end

  local jdtls_bin = vim.fn.exepath("jdtls")
  if jdtls_bin == "" then
    jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"
  end
  if vim.fn.executable(jdtls_bin) ~= 1 then
    vim.notify("jdtls is not installed yet. Run :MasonInstall jdtls", vim.log.levels.WARN)
    return
  end

  local jdk = resolve_jdk()
  if not jdk then
    if not warned_no_jdk then
      warned_no_jdk = true
      vim.notify(
        "No usable JDK found (set JAVA_HOME or `brew install openjdk`); jdtls not started",
        vim.log.levels.WARN
      )
    end
    return
  end

  local workspace_dir = vim.fn.stdpath("data")
    .. "/jdtls-workspaces/"
    .. vim.fn.sha256(root_dir):sub(1, 12)
    .. "-"
    .. vim.fn.fnamemodify(root_dir, ":t")

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local cok, blink = pcall(require, "blink.cmp")
  if cok and blink.get_lsp_capabilities then
    capabilities = blink.get_lsp_capabilities(capabilities)
  end

  jdtls.start_or_attach({
    cmd = { jdtls_bin, "--java-executable", jdk .. "/bin/java", "-data", workspace_dir },
    cmd_env = { JAVA_HOME = jdk, PATH = jdk .. "/bin:" .. (vim.env.PATH or "") },
    root_dir = root_dir,
    capabilities = capabilities,
    settings = {
      java = {
        configuration = {
          updateBuildConfiguration = "interactive",
          runtimes = { { name = "JavaSE-Default", path = jdk, default = true } },
        },
        format = { enabled = true },
        signatureHelp = { enabled = true },
        contentProvider = { preferred = "fernflower" },
      },
    },
    init_options = { bundles = {} },
  })
end

return M
