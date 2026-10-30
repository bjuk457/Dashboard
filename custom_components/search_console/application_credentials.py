"""Application credentials for Google Search Console."""

from homeassistant.components.application_credentials import AuthorizationServer
from homeassistant.core import HomeAssistant

from .const import OAUTH2_AUTHORIZE, OAUTH2_TOKEN


async def async_get_authorization_server(hass: HomeAssistant) -> AuthorizationServer:
    """Return the Google authorization server."""
    return AuthorizationServer(authorize_url=OAUTH2_AUTHORIZE, token_url=OAUTH2_TOKEN)


async def async_get_description_placeholders(hass: HomeAssistant) -> dict[str, str]:
    """Return placeholders shown when adding credentials."""
    return {
        "console_url": "https://console.cloud.google.com/apis/credentials",
        "redirect_url": "https://my.home-assistant.io/redirect/oauth",
    }
