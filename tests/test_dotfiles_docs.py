from __future__ import annotations

from pathlib import Path
import json
import unittest


class DotfilesDocsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.root = Path(__file__).resolve().parents[1]

    @classmethod
    def read(cls, rel: str) -> str:
        return (cls.root / rel).read_text(encoding='utf-8')

    def test_root_readme_uses_research_record_heading(self) -> None:
        text = self.read('README.md')
        self.assertIn('## Research record', text)
        self.assertNotIn('## Phase 0 status', text)

    def test_gitignore_covers_local_debug_artifacts(self) -> None:
        text = self.read('.gitignore')
        for pattern in (
            '.DS_Store',
            'tmp/',
            '.tmp-*/',
            '.pi-antigravity-research-tmp/',
            'nvim/trace_*.txt',
            'nvim/*.log',
        ):
            self.assertIn(pattern, text)

    def test_ghostty_workspace_is_part_of_managed_setup(self) -> None:
        self.assertTrue((self.root / 'ghostty').exists())
        self.assertFalse((self.root / 'alacritty').exists())
        readme = self.read('README.md')
        self.assertIn('ln -s "$(pwd)/ghostty" ~/.config/ghostty', readme)
        self.assertIn('ln -s "$(pwd)/git" ~/.config/git', readme)
        self.assertNotIn('ln -s "$(pwd)/alacritty" ~/.config/alacritty', readme)
        self.assertIn('ghostty/', readme)
        self.assertIn('open -a Ghostty', self.read('skhd/skhdrc'))
        self.assertIn('Open Ghostty', self.read('skhd/COMMANDS.md'))
        self.assertIn('Ghostty', self.read('yabai/yabairc'))

    def test_nvim_readme_matches_current_search_keymaps(self) -> None:
        text = self.read('nvim/README.md')
        self.assertIn('tree-sitter CLI', text)
        self.assertIn('Ghostty setup', text)
        for key in (
            '<leader>sf',
            '<leader>sg',
            '<leader>sr',
            '<leader>sb',
            '<leader>sd',
            '<leader>ss',
            '<leader>sk',
            '<leader>sw',
            '<leader>st',
        ):
            self.assertIn(key, text)
        for stale in (
            '<leader>ff',
            '<leader>fg',
            '<leader>fr',
            '<leader>fb',
            '<leader>fd',
            '<leader>fs',
            '<leader>fk',
            '<leader>ft',
            'rustaceanvim',
            ':RustLsp',
            'Alacritty setup',
        ):
            self.assertNotIn(stale, text)

    def test_nvim_prefers_one_chat_ui_plus_copilot(self) -> None:
        self.assertFalse((self.root / 'nvim' / 'lua' / 'ryanparker' / 'plugins' / 'avante.lua').exists())
        lock = json.loads(self.read('nvim/lazy-lock.json'))
        self.assertNotIn('avante.nvim', lock)
        self.assertIn('codecompanion.nvim', lock)
        self.assertIn('copilot.lua', lock)

    def test_providers_readme_no_longer_claims_phase0_only(self) -> None:
        text = self.read('providers/README.md')
        self.assertNotIn('No source-code adapters are generated in Phase 0.', text)
        self.assertNotIn('Implementation is blocked', text)
        for rel in (
            'providers/base.py',
            'providers/registry.py',
            'providers/claude/adapter.py',
            'providers/codex/adapter.py',
            'providers/antigravity/adapter.py',
        ):
            self.assertIn(rel, text)

    def test_tmux_config_has_no_machine_specific_repo_path(self) -> None:
        text = self.read('tmux/tmux.conf')
        self.assertNotIn('Documents/personal/code/dotfiles', text)
        self.assertIn('$HOME/.config/tmux/..', text)
        self.assertIn('xterm-ghostty:RGB', text)
        self.assertNotIn('alacritty:RGB', text)
        self.assertEqual(text.count('set -g pane-border-style'), 1)
        self.assertEqual(text.count('set -g pane-active-border-style'), 1)
        self.assertIn('@catppuccin_status_modules_left "session"', text)
        self.assertIn('@catppuccin_session_text "#{?client_prefix,PREFIX,#{?pane_in_mode,COPY,#S}}"', text)

    def test_tmux_reset_conf_shadowed_bindings_removed(self) -> None:
        text = self.read('tmux/tmux.reset.conf')
        self.assertNotIn('bind * list-clients', text)
        self.assertNotIn('bind l refresh-client', text)
        self.assertEqual(text.count('bind R source-file ~/.config/tmux/tmux.conf'), 1)

    def test_shell_config_uses_mise_and_atuin_instead_of_nvm(self) -> None:
        zshrc = self.read('zsh/.zshrc')
        zshenv = self.read('zsh/.zshenv')
        self.assertIn('mise activate zsh', zshrc)
        self.assertIn('atuin init zsh', zshrc)
        self.assertNotIn('nvm.sh', zshrc)
        self.assertNotIn('bash_completion', zshrc)
        self.assertIn('$HOME/.atuin/bin', zshenv)

    def test_git_config_enables_diff_and_signing_defaults(self) -> None:
        text = self.read('git/config')
        for expected in (
            'pager = delta',
            'diffFilter = delta --color-only',
            'enabled = true',
            'autoupdate = true',
            'format = ssh',
            'signingkey = ~/.ssh/ryan_parker.pub',
            'dlog = -c diff.external=difft log -p --ext-diff',
        ):
            self.assertIn(expected, text)
        self.assertTrue((self.root / 'git' / 'README.md').exists())

    def test_macos_space_counts_and_modes_are_aligned(self) -> None:
        yabai = self.read('yabai/yabairc')
        skhd = self.read('skhd/skhdrc')
        commands = self.read('skhd/COMMANDS.md')
        bar = self.read('sketchybar/sketchybarrc')
        bar_readme = self.read('sketchybar/README.md')

        self.assertIn('SPACE_COUNT=6', yabai)
        self.assertIn('ensure_space_count "$SPACE_COUNT"', yabai)
        self.assertIn('Ghostty', yabai)
        self.assertIn('SPACES="1 2 3 4 5 6"', bar)
        self.assertIn('Hyper + 1..6', commands)
        self.assertIn('open -a Ghostty', skhd)
        self.assertIn(':: resize @ : ~/.config/skhd/bin/set-mode resize', skhd)
        self.assertIn(':: warp @ : ~/.config/skhd/bin/set-mode warp', skhd)
        self.assertIn('Hyper + e', commands)
        self.assertIn('Hyper + w', commands)
        self.assertNotIn('space --focus 7', skhd)
        self.assertNotIn('window --space 7', skhd)
        self.assertIn('spaces `1..6`', bar_readme)

    def test_sketchybar_uses_batched_space_updates_and_mode_indicator(self) -> None:
        text = self.read('sketchybar/sketchybarrc')
        self.assertIn('spaces.worker', text)
        self.assertIn('script="$PLUGIN_DIR/spaces.sh"', text)
        self.assertIn('skhd_mode', text)
        self.assertIn('yabai_spaces_change', text)
        self.assertIn('yabai_front_app_change', text)
        self.assertIn('skhd_mode_change', text)
        self.assertNotIn('--subscribe "space.', text)


if __name__ == '__main__':
    unittest.main()
