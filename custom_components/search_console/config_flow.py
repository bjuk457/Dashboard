"""Config flow for Google Search Console."""

from __future__ import annotations

from collections.abc import Mapping
import logging
from typing import Any

import voluptuous as vol

from homeassistant.config_entries import (
    SOURCE_REAUTH,
    ConfigFlowResult,
    OptionsFlow,
)
from homeassistant.core import callback
from homeassistant.helpers import config_entry_oauth2_flow, config_validation as cv
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .api import SearchConsoleApi, SearchConsoleApiError, SearchConsoleAuthError
from .const import CONF_SITES, DOMAIN, OAUTH2_SCOPES
from .coordinator import SearchConsoleConfigEntry


def _sites_schema(sites: list[str], selected: list[str]) -> vol.Schema:
    return vol.Schema(
        {
            vol.Required(CONF_SITES, default=selected): cv.multi_select(
                {site: site for site in sites}
            )
        }
    )


class OAuth2FlowHandler(
    config_entry_oauth2_flow.AbstractOAuth2FlowHandler, domain=DOMAIN
):
    """Handle the Google sign-in and site selection."""

    DOMAIN = DOMAIN
    VERSION = 1

    def __init__(self) -> None:
        super().__init__()
        self._oauth_data: dict[str, Any] = {}
        self._sites: list[str] = []

    @property
    def logger(self) -> logging.Logger:
        return logging.getLogger(__name__)

    @property
    def extra_authorize_data(self) -> dict[str, Any]:
        # offline + consent makes Google hand out a refresh token.
        return {
            "scope": " ".join(OAUTH2_SCOPES),
            "access_type": "offline",
            "prompt": "consent",
        }

    async def async_step_reauth(
        self, entry_data: Mapping[str, Any]
    ) -> ConfigFlowResult:
        """Start over with Google when the token stopped working."""
        return await self.async_step_reauth_confirm()

    async def async_step_reauth_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is None:
            return self.async_show_form(step_id="reauth_confirm")
        return await self.async_step_user()

    async def async_oauth_create_entry(self, data: dict[str, Any]) -> ConfigFlowResult:
        """Called after Google returned a token."""
        if self.source == SOURCE_REAUTH:
            return self.async_update_reload_and_abort(
                self._get_reauth_entry(), data_updates=data
            )

        await self.async_set_unique_id(DOMAIN)
        self._abort_if_unique_id_configured()

        api = SearchConsoleApi(
            async_get_clientsession(self.hass),
            access_token=data["token"]["access_token"],
        )
        try:
            self._sites = await api.async_list_sites()
        except (SearchConsoleApiError, SearchConsoleAuthError):
            return self.async_abort(reason="cannot_connect")
        if not self._sites:
            return self.async_abort(reason="no_sites")

        self._oauth_data = data
        return await self.async_step_sites()

    async def async_step_sites(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        """Let the user pick which sites to track."""
        if user_input is not None:
            return self.async_create_entry(
                title="Google Search Console",
                data={**self._oauth_data, CONF_SITES: user_input[CONF_SITES]},
            )
        return self.async_show_form(
            step_id="sites", data_schema=_sites_schema(self._sites, self._sites)
        )

    @staticmethod
    @callback
    def async_get_options_flow(config_entry: SearchConsoleConfigEntry) -> OptionsFlow:
        return SearchConsoleOptionsFlow()


class SearchConsoleOptionsFlow(OptionsFlow):
    """Change the tracked sites later."""

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(data=user_input)

        coordinator = self.config_entry.runtime_data
        try:
            sites = await coordinator.api.async_list_sites()
        except (SearchConsoleApiError, SearchConsoleAuthError):
            return self.async_abort(reason="cannot_connect")
        return self.async_show_form(
            step_id="init",
            data_schema=_sites_schema(
                sites, [s for s in coordinator.site_urls if s in sites]
            ),
        )
