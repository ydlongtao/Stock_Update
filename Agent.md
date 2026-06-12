# Agent Notes

This project generates a weekday US ETF/asset brief for:

- QQQ
- VOO
- SCHD
- META
- ETH
- MSFT
- IBIT

## Daily Run

From the project root:

```bash
python3 scripts/generate_report.py
```

The script writes a self-contained HTML report to:

```text
reports/YYYY-MM-DD_us_etf_brief.html
```

It also stores raw Alpha Vantage responses in:

```text
data/
```

Both generated reports and raw data are ignored by Git.

## Automation

Codex automation:

```text
us-etf-daily-brief
```

Schedule: every weekday at 9:00 AM.

The automation should run `python3 scripts/generate_report.py`, then inspect the generated HTML report under `reports/`.

After the report is generated, run:

```bash
./scripts/launch_desktop_widget.sh
```

The launcher compiles and starts a small macOS desktop signal widget if it is not already running.

To stop the widget:

```bash
./scripts/stop_desktop_widget.sh
```

Current widget layout:

- Fixed 200x200 macOS desktop-level window.
- Desktop-level window so normal app windows appear above it.
- Header shows title and refresh time.
- Signal badge shows the overall daily signal.
- Watchlist symbols are arranged as a two-column grid to preserve a square layout.
- The bottom investment summary is constrained to two wrapped lines.
- Clicking the widget opens the full HTML report.

If changing the Swift UI, keep the window square and make sure long summary text cannot widen the window. The app sets min/max/content min/content max sizes to 200x200 for this reason.

## API Key Handling

Never commit API keys.

Local secrets live in:

```text
.env.local
```

This file is ignored by Git. Public examples should use:

```text
.env.example
```

Users can request a free Alpha Vantage API key at:

```text
https://www.alphavantage.co/support/#api-key
```

## Report Format

Reports are HTML, not Markdown.

The generator also writes the latest desktop widget payload to:

```text
data/latest_signal_widget.json
```

Signal colors:

- Green: positive momentum
- Gray: neutral
- Red: risk-off pressure
- Blue: observe / insufficient signal

## Maintenance Notes

- Keep the script dependency-free unless there is a strong reason to add packages.
- Preserve compatibility with `.env.local` loading from the project root.
- Keep generated files out of Git.
- Keep the desktop widget launcher idempotent so daily automation does not open duplicate windows.
- When widget source changes, `scripts/launch_desktop_widget.sh` should rebuild and restart the widget so the visible desktop window is not stale.
- If Alpha Vantage changes API behavior, prefer the smallest safe fix in `scripts/generate_report.py`.
- The investment view is informational research only, not personalized financial advice.
