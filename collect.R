library(httr2)
library(arrow)
library(jsonlite)
library(tidyverse)

# ── Phase 1 : Collect ────────────────────────────────────────────────────────

AV_KEY <- Sys.getenv("AV_KEY2")

# Gold
gold_hist_url <- paste0(
  "https://www.alphavantage.co/query?function=GOLD_SILVER_HISTORY",
  "&symbol=GOLD&interval=daily&apikey=", AV_KEY
)
gold_hist <- request(gold_hist_url) |>
  req_perform() |>
  resp_body_json() |>
  (`[[`)("data") |>
  bind_rows() |>
  transmute(
    date  = as.Date(date),
    gold  = as.numeric(price)
  )

# Brent
brent_hist_url <- paste0(
  "https://www.alphavantage.co/query?function=BRENT",
  "&interval=daily&apikey=", AV_KEY
)
brent_hist <- request(brent_hist_url) |>
  req_perform() |>
  resp_body_json() |>
  (`[[`)("data") |>
  bind_rows() |>
  transmute(
    date  = as.Date(date),
    brent = as.numeric(value)
  )

# 10Y Treasury
teny_hist_url <- paste0(
  "https://www.alphavantage.co/query?function=TREASURY_YIELD",
  "&interval=daily&maturity=10year&apikey=", AV_KEY
)
teny_hist <- request(teny_hist_url) |>
  req_perform() |>
  resp_body_json() |>
  (`[[`)("data") |>
  bind_rows() |>
  transmute(
    date  = as.Date(date),
    yield = as.numeric(value)
  )

# ── Phase 2 : Align & filter ─────────────────────────────────────────────────

# Gold series is the limit facto as it starts 2011-06-01 when the other two range from the sixties and the eighties to today.
panel <- gold_hist |>
  inner_join(brent_hist, by = "date") |>
  inner_join(teny_hist,  by = "date") |>
  filter(!is.na(gold), !is.na(brent), !is.na(yield)) |>
  arrange(date)

cat("Nb observations :", nrow(panel), "\n")

# ── Phase 3 : Save Parquet ───────────────────────────────────────────────────
if (!dir.exists("data")) dir.create("data")
write_parquet(panel, "data/macro_panel.parquet")
cat("Saved : data/macro_panel.parquet\n")
