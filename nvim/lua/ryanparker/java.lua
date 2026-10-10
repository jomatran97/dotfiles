local M = {}

local function command_ok(cmd)
  vim.fn.system(cmd)
  return vim.v.shell_error == 0
end

local function has_usable_jdk()
  return vim.fn.executable("java") == 1
    and vim.fn.executable("javac") == 1
    and command_ok({ "java", "-version" })
    and command_ok({ "javac", "-version" })
end

function M.start()
  local ok, jdtls = pcall(require, "jdtls")
  if not ok then
    vim.notify("nvim-jdtls is not installed yet. Run :Lazy sync", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local root_dir = vim.fs.root(bufnr, {
    ".git",
    "mvnw",
    "gradlew",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
  })
  if not root_dir then
    return
  end

  local jdtls_bin = vim.fn.stdpath("data") .. "/mason/bin/jdtls"
  if vim.fn.executable(jdtls_bin) ~= 1 then
    vim.notify("jdtls is not installed yet. Run :MasonInstall jdtls", vim.log.levels.WARN)
    return
  end

  if not has_usable_jdk() then
    vim.notify("Java needs a usable JDK (`java -version` and `javac -version`) before jdtls can start", vim.log.levels.WARN)
    return
  end

  local project_name = vim.fn.fnamemodify(root_dir, ":t")
  local workspace_dir = vim.fn.stdpath("data") .. "/jdtls-workspaces/" .. project_name

  jdtls.start_or_attach({
    cmd = { jdtls_bin, "-data", workspace_dir },
    root_dir = root_dir,
    settings = {
      java = {
        configuration = { updateBuildConfiguration = "interactive" },
        format = { enabled = true },
        signatureHelp = { enabled = true },
        contentProvider = { preferred = "fernflower" },
      },
    },
    init_options = { bundles = {} },
  })
end

return M
