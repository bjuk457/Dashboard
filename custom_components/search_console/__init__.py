"""The Google Search Console integration."""

from __future__ import annotations

from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryNotReady
from homeassistant.helpers import config_entry_oauth2_flow
from homeassistant.helpers.aiohttp_client import async_get_clientsession

from .api import SearchConsoleApi
from .coordinator import SearchConsoleConfigEntry, SearchConsoleCoordinator

PLATFORMS = [Platform.SENSOR]


async def async_setup_entry(hass: HomeAssistant, entry: SearchConsoleConfigEntry) -> bool:
    """Set up Search Console from a config entry."""
    try:
        implementation = (
            await config_entry_oauth2_flow.async_get_config_entry_implementation(
                hass, entry
            )
        )
    except ValueError as err:
        raise ConfigEntryNotReady("OAuth implementation not available") from err

    oauth_session = config_entry_oauth2_flow.OAuth2Session(hass, entry, implementation)
    api = SearchConsoleApi(async_get_clientsession(hass), oauth_session=oauth_session)

    coordinator = SearchConsoleCoordinator(hass, entry, api)
    await coordinator.async_config_entry_first_refresh()
    entry.runtime_data = coordinator

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    entry.async_on_unload(entry.add_update_listener(_async_reload_entry))
    return True


async def async_unload_entry(hass: HomeAssistant, entry: SearchConsoleConfigEntry) -> bool:
    """Unload a config entry."""
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)


async def _async_reload_entry(hass: HomeAssistant, entry: SearchConsoleConfigEntry) -> None:
    """Reload when the site selection changes."""
    await hass.config_entries.async_reload(entry.entry_id)
