# Appends the latest data points to the existing Parquet file.
# Designed to run once per trading day via cron or Azure Function.
# Cost : 3 Alpha Vantage API calls.

library(httr2)
library(arrow)
library(tidyverse)

# ── Config ───────────────────────────────────────────────────────────────────

AV_KEY      <- Sys.getenv("AV_KEY2")
PARQUET_PATH <- "data/macro_panel.parquet"

# ── Load existing panel ──────────────────────────────────────────────────────

panel   <- read_parquet(PARQUET_PATH)
last_date <- max(panel$date)
cat("Last date in panel :", format(last_date), "\n")

# ── Fetch latest data ────────────────────────────────────────────────────────

fetch_av <- function(url) {
  Sys.sleep(2)
  request(url) |>
    req_perform() |>
    resp_body_json()
}

# Gold
rep_gold <- fetch_av(paste0(
  "https://www.alphavantage.co/query?function=GOLD_SILVER_HISTORY",
  "&symbol=GOLD&interval=daily&apikey=", AV_KEY
))
gold_new <- bind_rows(rep_gold$data) |>
  transmute(date = as.Date(date), gold = as.numeric(price)) |>
  filter(date > last_date)

## Brent
#rep_brent <- fetch_av(paste0(
#  "https://www.alphavantage.co/query?function=BRENT",
#  "&interval=daily&apikey=", AV_KEY
#))
#brent_new <- bind_rows(rep_brent$data) |>
#  transmute(date = as.Date(date), brent = as.numeric(value)) |>
#  filter(date > last_date)

# 10Y Treasury
rep_teny <- fetch_av(paste0(
  "https://www.alphavantage.co/query?function=TREASURY_YIELD",
  "&interval=daily&maturity=10year&apikey=", AV_KEY
))
teny_new <- bind_rows(rep_teny$data) |>
  transmute(date = as.Date(date), yield = as.numeric(value)) |>
  filter(date > last_date)

# ── Join new rows ─────────────────────────────────────────────────────────────

new_rows <- gold_new |>
  inner_join(teny_new,  by = "date") |>
  filter(!is.na(gold), !is.na(yield)) |>
  arrange(date)

# ── Append & save ─────────────────────────────────────────────────────────────

if (nrow(new_rows) == 0) {
  cat("No new data available — panel is already up to date.\n")
} else {
  panel_updated <- bind_rows(panel, new_rows) |>
    arrange(date)
  
  write_parquet(panel_updated, PARQUET_PATH)
  
  cat("Rows added        :", nrow(new_rows), "\n")
  cat("New last date     :", format(max(panel_updated$date)), "\n")
  cat("Total observations:", nrow(panel_updated), "\n")
}
