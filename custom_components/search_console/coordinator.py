"""Data coordinator for Google Search Console."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
from datetime import date, timedelta
import logging
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryAuthFailed
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed
from homeassistant.util import dt as dt_util

from .api import SearchConsoleApi, SearchConsoleApiError, SearchConsoleAuthError
from .const import (
    CONF_SITES,
    DATA_DELAY_DAYS,
    DOMAIN,
    MOVERS,
    PERIOD_DAYS,
    QUERY_ROW_LIMIT,
    TOP_QUERIES,
    UPDATE_INTERVAL,
)

_LOGGER = logging.getLogger(__name__)

type SearchConsoleConfigEntry = ConfigEntry[SearchConsoleCoordinator]


@dataclass
class SiteData:
    """Figures for one site, current period against the previous one."""

    totals: dict[str, float]
    previous_totals: dict[str, float]
    top_queries: list[dict[str, Any]] = field(default_factory=list)
    winners: list[dict[str, Any]] = field(default_factory=list)
    losers: list[dict[str, Any]] = field(default_factory=list)


@dataclass
class SearchConsoleData:
    """Everything the sensors read."""

    start_date: date
    end_date: date
    sites: dict[str, SiteData]


def _totals(rows: list[dict[str, Any]]) -> dict[str, float]:
    if not rows:
        return {"clicks": 0, "impressions": 0, "ctr": 0.0, "position": 0.0}
    row = rows[0]
    return {
        "clicks": int(row.get("clicks", 0)),
        "impressions": int(row.get("impressions", 0)),
        "ctr": round(row.get("ctr", 0.0) * 100, 2),
        "position": round(row.get("position", 0.0), 1),
    }


def _by_query(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {row["keys"][0]: row for row in rows}


def _query_entry(
    query: str, current: dict[str, Any] | None, previous: dict[str, Any] | None
) -> dict[str, Any]:
    current = current or {}
    previous = previous or {}
    clicks = int(current.get("clicks", 0))
    prev_clicks = int(previous.get("clicks", 0))
    position = current.get("position")
    prev_position = previous.get("position")
    return {
        "query": query,
        "clicks": clicks,
        "impressions": int(current.get("impressions", 0)),
        "ctr": round(current.get("ctr", 0.0) * 100, 1),
        "position": round(position, 1) if position is not None else None,
        "clicks_change": clicks - prev_clicks,
        # Positive means the query moved up in the results.
        "position_change": (
            round(prev_position - position, 1)
            if position is not None and prev_position is not None
            else None
        ),
    }


class SearchConsoleCoordinator(DataUpdateCoordinator[SearchConsoleData]):
    """Fetch Search Console figures for the selected sites."""

    config_entry: SearchConsoleConfigEntry

    def __init__(
        self,
        hass: HomeAssistant,
        entry: SearchConsoleConfigEntry,
        api: SearchConsoleApi,
    ) -> None:
        super().__init__(
            hass,
            _LOGGER,
            config_entry=entry,
            name=DOMAIN,
            update_interval=UPDATE_INTERVAL,
        )
        self.api = api

    @property
    def site_urls(self) -> list[str]:
        """Sites chosen in the options, falling back to the initial setup."""
        return self.config_entry.options.get(
            CONF_SITES, self.config_entry.data.get(CONF_SITES, [])
        )

    async def _async_update_data(self) -> SearchConsoleData:
        end = dt_util.now().date() - timedelta(days=DATA_DELAY_DAYS)
        start = end - timedelta(days=PERIOD_DAYS - 1)
        prev_end = start - timedelta(days=1)
        prev_start = prev_end - timedelta(days=PERIOD_DAYS - 1)

        try:
            results = await asyncio.gather(
                *(
                    self._fetch_site(site, start, end, prev_start, prev_end)
                    for site in self.site_urls
                )
            )
        except SearchConsoleAuthError as err:
            raise ConfigEntryAuthFailed(str(err)) from err
        except SearchConsoleApiError as err:
            raise UpdateFailed(str(err)) from err

        return SearchConsoleData(
            start_date=start,
            end_date=end,
            sites=dict(zip(self.site_urls, results, strict=True)),
        )

    async def _fetch_site(
        self,
        site: str,
        start: date,
        end: date,
        prev_start: date,
        prev_end: date,
    ) -> SiteData:
        s, e = start.isoformat(), end.isoformat()
        ps, pe = prev_start.isoformat(), prev_end.isoformat()
        totals, prev_totals, queries, prev_queries = await asyncio.gather(
            self.api.async_query(site, s, e),
            self.api.async_query(site, ps, pe),
            self.api.async_query(site, s, e, ["query"], QUERY_ROW_LIMIT),
            self.api.async_query(site, ps, pe, ["query"], QUERY_ROW_LIMIT),
        )

        current = _by_query(queries)
        previous = _by_query(prev_queries)
        entries = {
            query: _query_entry(query, current.get(query), previous.get(query))
            for query in current.keys() | previous.keys()
        }

        top = sorted(
            (entries[q] for q in current),
            key=lambda e: (e["clicks"], e["impressions"]),
            reverse=True,
        )[:TOP_QUERIES]
        by_change = sorted(entries.values(), key=lambda e: e["clicks_change"])
        winners = [e for e in reversed(by_change) if e["clicks_change"] > 0][:MOVERS]
        losers = [e for e in by_change if e["clicks_change"] < 0][:MOVERS]

        return SiteData(
            totals=_totals(totals),
            previous_totals=_totals(prev_totals),
            top_queries=top,
            winners=winners,
            losers=losers,
        )
