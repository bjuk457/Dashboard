"""Constants for the Google Search Console integration."""

from datetime import timedelta

DOMAIN = "search_console"

OAUTH2_AUTHORIZE = "https://accounts.google.com/o/oauth2/v2/auth"
OAUTH2_TOKEN = "https://oauth2.googleapis.com/token"
OAUTH2_SCOPES = ["https://www.googleapis.com/auth/webmasters.readonly"]

API_BASE = "https://www.googleapis.com/webmasters/v3"

CONF_SITES = "sites"

UPDATE_INTERVAL = timedelta(hours=6)

# Search Console finalizes data with a delay of roughly two to three days.
DATA_DELAY_DAYS = 3
PERIOD_DAYS = 28

TOP_QUERIES = 25
MOVERS = 5
QUERY_ROW_LIMIT = 1000
