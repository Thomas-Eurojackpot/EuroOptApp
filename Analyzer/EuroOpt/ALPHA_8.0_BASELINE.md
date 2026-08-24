# ALPHA 8.0 – WORKING BASELINE

Stand: 24.08.2026

Dieser Stand ist als Referenzpunkt vor weiteren Hill-Climbing-Experimenten gesichert.

## Getestete Alpha-8.0-Logik
- 581 Ziehungen
- 9 Tipps je Ziehung
- Hill Climbing im aktuellen separaten Backtest: 30 Iterationen (`AppSettings.backtestHillClimbingIterations`)
- Auswahl: Score → Top 27 → Coverage-Auswahl → 9 Tipps
- Gewinndefinition: 3+0 oder besser ODER 2+1 oder besser
- Vergleich: Ralf vs. Zufall

## Letztes vollständiges Ergebnis (HC30)
- Alpha 8.0: 101 / 17,4 % Gewinnziehungen; 109 Gewinn-Tickets
- Ralf: 123 / 21,2 % Gewinnziehungen; 148 Gewinn-Tickets
- Zufall: 139 / 23,9 % Gewinnziehungen; 158 Gewinn-Tickets

## Verwendete lokale Dateien
- `OptimizerView.swift`
- `OptimizerViewModel_FINAL.swift` → in Xcode als `OptimizerViewModel.swift`
- `Alpha80VsRalfVsRandomBacktestDiagnostic_HC30.swift` → in Xcode als `Alpha80VsRalfVsRandomBacktestDiagnostic.swift`

## SHA-256 der getesteten lokalen Dateien
- OptimizerView.swift: `a9180a394c3b17834b67d53dcce03fee484f434f2554ea12013217f472f7a501`
- OptimizerViewModel_FINAL.swift: `5770be4ba25589fd327b24078518fcb343fe645b82156e94720dcef12a53fc1f`
- Alpha80VsRalfVsRandomBacktestDiagnostic_HC30.swift: `7bab0c1e92187a8c6b3f253d6cdabe053f33790eb480ad51de7eb5954a`

Dieser Marker dient als GitHub-Sicherung des aktuellen Alpha-8.0-Arbeitsstands. Weitere Experimente sollen davon getrennt betrachtet werden.
