# Script to synchronize all standardized issue labels to the GitHub repository using gh CLI.
param(
    [string]$Repo = "kandraos3/Telly"
)

$labels = @(
    # Types
    @{ Name = "bug"; Color = "FF4B6E"; Desc = "Something isn't working as expected or breaks invariants" },
    @{ Name = "enhancement"; Color = "D2FF52"; Desc = "New feature, quality-of-life upgrade, or refinement" },
    @{ Name = "feature"; Color = "7C5CFF"; Desc = "Major new functional capability" },
    @{ Name = "design"; Color = "FFA733"; Desc = "UI/UX styling, typography, spacing, or visual tokens" },

    # Areas
    @{ Name = "area:auth"; Color = "6E7681"; Desc = "Authentication, onboarding, and legal terms (SCR-01)" },
    @{ Name = "area:logging"; Color = "D2FF52"; Desc = "Title logging studio and sentiment capture (SCR-09, SCR-12)" },
    @{ Name = "area:ranking"; Color = "FFA733"; Desc = "Binary search tournament, Elo/TrueSkill, and percentiles" },
    @{ Name = "area:profile"; Color = "7C5CFF"; Desc = "User profile, dual-canon lists, and analytics (SCR-14, SCR-15)" },
    @{ Name = "area:title-detail"; Color = "2EA043"; Desc = "Movie and TV show detail screen, cast & providers (SCR-08)" },
    @{ Name = "area:explore"; Color = "0075CA"; Desc = "Explore, curated canons, discovery, and search (SCR-07)" },
    @{ Name = "area:squads"; Color = "A371F7"; Desc = "Squads list, hub, Borda count aggregation (SCR-17)" },
    @{ Name = "area:co-watch"; Color = "E85AAD"; Desc = "Two-to-Watch taste compatibility & quick swipe duel (SCR-16)" },
    @{ Name = "area:queue"; Color = "F9D0C4"; Desc = "Smart queue, custom user lists, and watchlist sharing (SCR-13)" },
    @{ Name = "area:feed"; Color = "1D76DB"; Desc = "Social activity feed, upsets, and reactions (SCR-05)" },
    @{ Name = "area:settings"; Color = "8A99AD"; Desc = "Settings hub, account deletion, and data import/export (SCR-20)" },
    @{ Name = "area:theme"; Color = "E36209"; Desc = "Day Cathode light mode, dark mode, and theme switching" },

    # Priorities
    @{ Name = "p0-blocker"; Color = "B60205"; Desc = "Critical blocker: crash, build failure, data corruption" },
    @{ Name = "p1-high"; Color = "D93F0B"; Desc = "High priority: broken core flow, wrong math, major visual glitch" },
    @{ Name = "p2-medium"; Color = "FBCA04"; Desc = "Medium priority: UX polish, missing secondary action, minor bug" },
    @{ Name = "p3-low"; Color = "0E8A16"; Desc = "Low priority: cosmetic enhancement or nice-to-have" },

    # Status
    @{ Name = "status:triage"; Color = "CCCCCC"; Desc = "Newly ingested feedback awaiting specification" },
    @{ Name = "status:ready"; Color = "0E8A16"; Desc = "Fully specified with acceptance criteria, ready for pickup" },
    @{ Name = "status:in-progress"; Color = "FBCA04"; Desc = "Actively being implemented on a feature branch" },
    @{ Name = "status:review"; Color = "1D76DB"; Desc = "PR opened and pending code review or CI check" },
    @{ Name = "status:done"; Color = "0366D6"; Desc = "Merged to main and verified" }
)

Write-Host "Syncing standardized labels to $Repo..."
foreach ($lbl in $labels) {
    gh label create $lbl.Name --repo $Repo --color $lbl.Color --description $lbl.Desc --force 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] $($lbl.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [ERR] $($lbl.Name)" -ForegroundColor Red
    }
}
Write-Host "Label sync complete."
