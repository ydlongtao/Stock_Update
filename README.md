# US ETF Daily Brief

This workspace generates a weekday 9:00 AM US market brief focused on:

- QQQ
- VOO
- SCHD
- META
- ETH
- MSFT
- IBIT

Reports are saved under `reports/` as self-contained HTML files. Raw API responses are saved under `data/` for auditability.

The HTML report uses color-coded signal badges:

- Green: positive momentum
- Gray: neutral
- Red: risk-off pressure
- Blue: observe / insufficient signal

## API Key

Create a free Alpha Vantage API key at:

https://www.alphavantage.co/support/#api-key

Then create your local `.env.local` file:

```bash
cp .env.example .env.local
```

Edit `.env.local` and replace `replace_with_your_free_alpha_vantage_key` with your own key.

Do not commit `.env.local`; it is intentionally ignored by Git.

## Run Manually

```bash
python3 scripts/generate_report.py
```

The script prints the saved report path, for example:

```text
reports/2026-06-11_us_etf_brief.html
```

## Desktop Widget

To show the latest investment signal in a small macOS desktop widget:

```bash
./scripts/launch_desktop_widget.sh
```

To keep it running after login and update it every weekday at 9:00 AM:

```bash
./scripts/install_launch_agents.sh
```

This installs one user LaunchAgent:

- `com.stockupdate.signal-widget`: starts the widget at login and restarts it if it exits.

The widget checks the clock once per minute. On weekdays after 9:00 AM, if today's update has not run yet, it regenerates the HTML report and `data/latest_signal_widget.json`.

To close it:

```bash
./scripts/stop_desktop_widget.sh
```

To remove the login LaunchAgent:

```bash
./scripts/uninstall_launch_agents.sh
```

The widget reads:

```text
data/latest_signal_widget.json
```

Click the widget to open the full HTML report. The widget is placed at desktop level so normal app windows can cover it. The launcher is safe to run repeatedly; it will not open duplicate widgets if one is already running.

LaunchAgent logs are written under:

```text
logs/
```

## Notes

- Alpha Vantage is used for quotes, ETH daily prices, and news sentiment.
- The generator reads recent saved reports and includes a continuity section so recommendations can evolve over time.
- This is an informational research brief, not personalized financial advice.
