"""Minimal async client for the Search Console API."""

from __future__ import annotations

from typing import Any
from urllib.parse import quote

from aiohttp import ClientResponseError, ClientSession

from homeassistant.helpers import config_entry_oauth2_flow

from .const import API_BASE


class SearchConsoleAuthError(Exception):
    """Raised when Google rejects the access token."""


class SearchConsoleApiError(Exception):
    """Raised for any other API failure."""


class SearchConsoleApi:
    """Talk to the Search Console API with a bearer token."""

    def __init__(
        self,
        session: ClientSession,
        oauth_session: config_entry_oauth2_flow.OAuth2Session | None = None,
        access_token: str | None = None,
    ) -> None:
        self._session = session
        self._oauth_session = oauth_session
        self._access_token = access_token

    async def _token(self) -> str:
        if self._oauth_session is None:
            return self._access_token or ""
        await self._oauth_session.async_ensure_token_valid()
        return self._oauth_session.token["access_token"]

    async def _request(
        self, method: str, path: str, json: dict[str, Any] | None = None
    ) -> dict[str, Any]:
        headers = {"Authorization": f"Bearer {await self._token()}"}
        try:
            async with self._session.request(
                method, f"{API_BASE}{path}", json=json, headers=headers
            ) as resp:
                if resp.status == 401:
                    raise SearchConsoleAuthError(await resp.text())
                resp.raise_for_status()
                return await resp.json()
        except ClientResponseError as err:
            raise SearchConsoleApiError(str(err)) from err

    async def async_list_sites(self) -> list[str]:
        """Return the URLs of all sites the account may read."""
        data = await self._request("GET", "/sites")
        return sorted(
            entry["siteUrl"]
            for entry in data.get("siteEntry", [])
            if entry.get("permissionLevel") != "siteUnverifiedUser"
        )

    async def async_query(
        self,
        site_url: str,
        start_date: str,
        end_date: str,
        dimensions: list[str] | None = None,
        row_limit: int = 1000,
    ) -> list[dict[str, Any]]:
        """Run a searchAnalytics query and return its rows."""
        body: dict[str, Any] = {
            "startDate": start_date,
            "endDate": end_date,
            "rowLimit": row_limit,
        }
        if dimensions:
            body["dimensions"] = dimensions
        data = await self._request(
            "POST",
            f"/sites/{quote(site_url, safe='')}/searchAnalytics/query",
            json=body,
        )
        return data.get("rows", [])
