-- ~/.config/nvim/init.lua
-- Entry point. `ryanparker.core` loads first (it sets the leader key and disables
-- netrw before any plugin loads), then `ryanparker.lazy` bootstraps the plugins.
require("ryanparker.core")
require("ryanparker.lazy")
