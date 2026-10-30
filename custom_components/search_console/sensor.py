"""Sensors for Google Search Console."""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlparse

from homeassistant.components.sensor import (
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import PERCENTAGE
from homeassistant.core import HomeAssistant
from homeassistant.helpers.device_registry import DeviceEntryType, DeviceInfo
from homeassistant.helpers.entity_platform import AddConfigEntryEntitiesCallback
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import SearchConsoleConfigEntry, SearchConsoleCoordinator, SiteData


@dataclass(frozen=True, kw_only=True)
class SearchConsoleSensorDescription(SensorEntityDescription):
    """Describes one figure of a site."""

    value_fn: Callable[[SiteData], Any]
    attrs_fn: Callable[[SiteData], dict[str, Any]] = lambda _: {}


def _change(key: str) -> Callable[[SiteData], dict[str, Any]]:
    def attrs(site: SiteData) -> dict[str, Any]:
        current = site.totals[key]
        previous = site.previous_totals[key]
        return {
            "previous": previous,
            "change": round(current - previous, 2),
            "change_percent": (
                round((current - previous) / previous * 100, 1) if previous else None
            ),
        }

    return attrs


SENSORS: tuple[SearchConsoleSensorDescription, ...] = (
    SearchConsoleSensorDescription(
        key="clicks",
        translation_key="clicks",
        icon="mdi:cursor-default-click",
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda site: site.totals["clicks"],
        attrs_fn=_change("clicks"),
    ),
    SearchConsoleSensorDescription(
        key="impressions",
        translation_key="impressions",
        icon="mdi:eye",
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda site: site.totals["impressions"],
        attrs_fn=_change("impressions"),
    ),
    SearchConsoleSensorDescription(
        key="ctr",
        translation_key="ctr",
        icon="mdi:percent",
        native_unit_of_measurement=PERCENTAGE,
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda site: site.totals["ctr"],
        attrs_fn=_change("ctr"),
    ),
    SearchConsoleSensorDescription(
        key="position",
        translation_key="position",
        icon="mdi:podium",
        state_class=SensorStateClass.MEASUREMENT,
        value_fn=lambda site: site.totals["position"],
        attrs_fn=_change("position"),
    ),
    SearchConsoleSensorDescription(
        key="top_queries",
        translation_key="top_queries",
        icon="mdi:magnify",
        value_fn=lambda site: (
            site.top_queries[0]["query"][:255] if site.top_queries else None
        ),
        attrs_fn=lambda site: {
            "queries": site.top_queries,
            "winners": site.winners,
            "losers": site.losers,
        },
    ),
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: SearchConsoleConfigEntry,
    async_add_entities: AddConfigEntryEntitiesCallback,
) -> None:
    """Create the sensors for every tracked site."""
    coordinator = entry.runtime_data
    async_add_entities(
        SearchConsoleSensor(coordinator, site, description)
        for site in coordinator.site_urls
        for description in SENSORS
    )


class SearchConsoleSensor(CoordinatorEntity[SearchConsoleCoordinator], SensorEntity):
    """One figure for one site."""

    _attr_has_entity_name = True
    _unrecorded_attributes = frozenset({"queries", "winners", "losers"})
    entity_description: SearchConsoleSensorDescription

    def __init__(
        self,
        coordinator: SearchConsoleCoordinator,
        site: str,
        description: SearchConsoleSensorDescription,
    ) -> None:
        super().__init__(coordinator)
        self.entity_description = description
        self._site = site
        host = urlparse(site).netloc or site.removeprefix("sc-domain:")
        self._attr_unique_id = f"{site}_{description.key}"
        self._attr_device_info = DeviceInfo(
            identifiers={(DOMAIN, site)},
            name=host,
            manufacturer="Google",
            model="Search Console",
            entry_type=DeviceEntryType.SERVICE,
            configuration_url=f"https://search.google.com/search-console?resource_id={site}",
        )

    @property
    def _site_data(self) -> SiteData | None:
        return self.coordinator.data.sites.get(self._site)

    @property
    def available(self) -> bool:
        return super().available and self._site_data is not None

    @property
    def native_value(self) -> Any:
        return self.entity_description.value_fn(self._site_data)

    @property
    def extra_state_attributes(self) -> dict[str, Any]:
        data = self.coordinator.data
        return {
            "start_date": data.start_date.isoformat(),
            "end_date": data.end_date.isoformat(),
            **self.entity_description.attrs_fn(self._site_data),
        }
