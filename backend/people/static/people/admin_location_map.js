(function () {
  const DEFAULT_CENTER = [13.058889689752338, 77.54593290059762];
  const DEFAULT_ZOOM = 16;
  const COORDINATE_PRECISION = 15;

  function ready(callback) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', callback);
    } else {
      callback();
    }
  }

  function fieldPrefix(input) {
    const id = input.id || '';
    return id.endsWith('latitude_longitude')
      ? id.slice(0, -'latitude_longitude'.length)
      : '';
  }

  function fieldById(prefix, name) {
    return document.getElementById(`${prefix}${name}`);
  }

  function parseCoordinatePair(value) {
    const match = String(value || '')
      .trim()
      .match(/^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/);
    if (!match) return null;
    const latitude = Number(match[1]);
    const longitude = Number(match[2]);
    if (
      !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180
    ) {
      return null;
    }
    return { latitude, longitude };
  }

  function formatCoordinate(value) {
    return Number(value).toFixed(COORDINATE_PRECISION).replace(/0+$/, '').replace(/\.$/, '');
  }

  function cssEscape(value) {
    if (window.CSS && typeof window.CSS.escape === 'function') {
      return window.CSS.escape(value);
    }
    return String(value).replace(/["\\]/g, '\\$&');
  }

  function buildPanel() {
    const panel = document.createElement('div');
    panel.className = 'healon-location-map-panel';
    panel.innerHTML = `
      <div class="healon-location-map-toolbar">
        <input class="healon-location-search-input" type="search" placeholder="Search place or office address">
        <button class="healon-location-map-button" type="button">Search</button>
        <button class="healon-location-map-button secondary" type="button">Use Current Location</button>
      </div>
      <div class="healon-location-map" aria-label="Assign office location map"></div>
      <div class="healon-location-map-status">
        <div><span>Latitude</span><strong data-location-latitude>-</strong></div>
        <div><span>Longitude</span><strong data-location-longitude>-</strong></div>
        <div><span>Selected Address</span><strong data-location-address>Move the pin or search an address</strong></div>
      </div>
      <div class="healon-location-map-message">Search, click the map, drag the pin, or use current location to set attendance coordinates.</div>
    `;
    return panel;
  }

  function setMessage(panel, text, isError) {
    const message = panel.querySelector('.healon-location-map-message');
    if (!message) return;
    message.textContent = text;
    message.classList.toggle('error', Boolean(isError));
  }

  function debounce(callback, delay) {
    let timer = null;
    return function (...args) {
      window.clearTimeout(timer);
      timer = window.setTimeout(() => callback.apply(this, args), delay);
    };
  }

  function setupLocationPicker(input) {
    if (input.dataset.healonLocationMapReady === '1') return;
    input.dataset.healonLocationMapReady = '1';

    const prefix = fieldPrefix(input);
    const latitudeField = fieldById(prefix, 'latitude');
    const longitudeField = fieldById(prefix, 'longitude');
    const coordinatesResolvedField = fieldById(prefix, 'coordinates_resolved');
    const addressField = fieldById(prefix, 'address');
    const mapUrlField = fieldById(prefix, 'map_url');
    const mapLocationField = fieldById(prefix, 'map_location');
    const radiusField = fieldById(prefix, 'radius_meters');
    const row = input.closest('.form-row, .form-group, .field-latitude_longitude') || input.parentElement;
    if (!row) return;

    const panel = buildPanel();
    row.insertAdjacentElement('afterend', panel);

    if (!window.L) {
      setMessage(panel, 'Map library could not be loaded. Enter valid latitude,longitude manually.', true);
      return;
    }

    const mapElement = panel.querySelector('.healon-location-map');
    const searchInput = panel.querySelector('.healon-location-search-input');
    const searchButton = panel.querySelector('.healon-location-map-button');
    const currentButton = panel.querySelector('.healon-location-map-button.secondary');
    const latitudePreview = panel.querySelector('[data-location-latitude]');
    const longitudePreview = panel.querySelector('[data-location-longitude]');
    const addressPreview = panel.querySelector('[data-location-address]');

    const initialPair =
      parseCoordinatePair(input.value) ||
      parseCoordinatePair(`${latitudeField ? latitudeField.value : ''},${longitudeField ? longitudeField.value : ''}`);
    const initialCenter = initialPair
      ? [initialPair.latitude, initialPair.longitude]
      : DEFAULT_CENTER;

    const map = window.L.map(mapElement, {
      zoomControl: true,
      scrollWheelZoom: true,
    }).setView(initialCenter, initialPair ? DEFAULT_ZOOM : 13);

    window.L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 20,
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);

    const marker = window.L.marker(initialCenter, { draggable: true }).addTo(map);
    let radiusCircle = null;

    function radiusMeters() {
      const radius = Number(radiusField ? radiusField.value : 100);
      return Number.isFinite(radius) && radius > 0 ? radius : 100;
    }

    function updateRadiusCircle(latitude, longitude) {
      if (radiusCircle) {
        radiusCircle.setLatLng([latitude, longitude]);
        radiusCircle.setRadius(radiusMeters());
        return;
      }
      radiusCircle = window.L.circle([latitude, longitude], {
        radius: radiusMeters(),
        color: '#10b981',
        weight: 2,
        fillColor: '#10b981',
        fillOpacity: 0.12,
      }).addTo(map);
    }

    async function reverseGeocode(latitude, longitude) {
      try {
        const response = await fetch(
          `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${encodeURIComponent(latitude)}&lon=${encodeURIComponent(longitude)}`,
          { headers: { Accept: 'application/json' } },
        );
        if (!response.ok) return;
        const data = await response.json();
        const label = data.display_name || '';
        if (label) {
          addressPreview.textContent = label;
          if (addressField && !addressField.value.trim()) {
            addressField.value = label;
          }
        }
      } catch (error) {
        setMessage(panel, 'Coordinates updated. Address preview is unavailable right now.', false);
      }
    }

    const updateAddressPreview = debounce(reverseGeocode, 450);

    function applyCoordinates(latitude, longitude, options) {
      const latText = formatCoordinate(latitude);
      const lonText = formatCoordinate(longitude);
      input.value = `${latText},${lonText}`;
      if (latitudeField) latitudeField.value = latText;
      if (longitudeField) longitudeField.value = lonText;
      if (coordinatesResolvedField) coordinatesResolvedField.value = 'True';
      if (mapLocationField) mapLocationField.value = `https://www.google.com/maps?q=${latText},${lonText}`;
      if (mapUrlField) mapUrlField.value = `https://www.google.com/maps?q=${latText},${lonText}`;
      latitudePreview.textContent = latText;
      longitudePreview.textContent = lonText;
      marker.setLatLng([latitude, longitude]);
      updateRadiusCircle(latitude, longitude);
      if (!options || options.pan !== false) {
        map.setView([latitude, longitude], Math.max(map.getZoom(), DEFAULT_ZOOM));
      }
      input.dispatchEvent(new Event('change', { bubbles: true }));
      setMessage(panel, 'Selected coordinates are ready to save.', false);
      updateAddressPreview(latitude, longitude);
    }

    async function searchLocation() {
      const query = searchInput.value.trim();
      if (!query) {
        setMessage(panel, 'Enter a place or address to search.', true);
        return;
      }
      searchButton.disabled = true;
      setMessage(panel, 'Searching location...', false);
      try {
        const response = await fetch(
          `https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=${encodeURIComponent(query)}`,
          { headers: { Accept: 'application/json' } },
        );
        const results = response.ok ? await response.json() : [];
        if (!results.length) {
          setMessage(panel, 'No matching location found. Try a more complete address.', true);
          return;
        }
        const result = results[0];
        const latitude = Number(result.lat);
        const longitude = Number(result.lon);
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
          setMessage(panel, 'Search returned invalid coordinates.', true);
          return;
        }
        if (addressField) addressField.value = result.display_name || query;
        addressPreview.textContent = result.display_name || query;
        applyCoordinates(latitude, longitude);
      } catch (error) {
        setMessage(panel, 'Location search is unavailable. Enter coordinates manually or try again.', true);
      } finally {
        searchButton.disabled = false;
      }
    }

    function useCurrentLocation() {
      if (!navigator.geolocation) {
        setMessage(panel, 'Current location is not available in this browser.', true);
        return;
      }
      currentButton.disabled = true;
      setMessage(panel, 'Getting current location...', false);
      navigator.geolocation.getCurrentPosition(
        (position) => {
          applyCoordinates(position.coords.latitude, position.coords.longitude);
          currentButton.disabled = false;
        },
        () => {
          setMessage(panel, 'Unable to get current location. Allow location permission and try again.', true);
          currentButton.disabled = false;
        },
        { enableHighAccuracy: true, maximumAge: 0, timeout: 15000 },
      );
    }

    marker.on('dragend', function () {
      const point = marker.getLatLng();
      applyCoordinates(point.lat, point.lng, { pan: false });
    });

    map.on('click', function (event) {
      applyCoordinates(event.latlng.lat, event.latlng.lng);
    });

    input.addEventListener('change', function () {
      const pair = parseCoordinatePair(input.value);
      if (!pair) {
        setMessage(panel, 'Coordinate entry is invalid. Use latitude,longitude.', true);
        return;
      }
      applyCoordinates(pair.latitude, pair.longitude);
    });

    if (radiusField) {
      radiusField.addEventListener('input', function () {
        const pair = parseCoordinatePair(input.value);
        if (pair) updateRadiusCircle(pair.latitude, pair.longitude);
      });
    }

    const form = input.closest('form');
    if (form && form.dataset.healonLocationSubmitGuard !== '1') {
      form.dataset.healonLocationSubmitGuard = '1';
      form.addEventListener('submit', function (event) {
        const invalidPicker = Array.from(
          form.querySelectorAll('input[name$="latitude_longitude"]'),
        ).find((coordinateInput) => {
          const activeName = coordinateInput.name.replace(/latitude_longitude$/, 'is_active');
          const checked = form.querySelector(`input[name="${cssEscape(activeName)}"]:checked`);
          const enabled = !checked || ['true', 'True', '1'].includes(String(checked.value));
          const pair = parseCoordinatePair(coordinateInput.value);
          return enabled && (!pair || (pair.latitude === 0 && pair.longitude === 0));
        });
        const invalidRadius = Array.from(form.querySelectorAll('input[name$="radius_meters"]'))
          .find((radiusInput) => Number(radiusInput.value) <= 0);
        if (invalidPicker || invalidRadius) {
          event.preventDefault();
          const targetInput = invalidPicker || invalidRadius;
          const targetPanel = targetInput
            .closest('.form-row, .form-group, .field-latitude_longitude')
            ?.nextElementSibling;
          if (targetPanel && targetPanel.classList.contains('healon-location-map-panel')) {
            setMessage(
              targetPanel,
              invalidRadius
                ? 'Allowed radius must be greater than 0 meters.'
                : 'Select a valid map pin or enter latitude,longitude before saving.',
              true,
            );
          }
          targetInput.focus();
        }
      });
    }

    searchButton.addEventListener('click', searchLocation);
    searchInput.addEventListener('keydown', function (event) {
      if (event.key === 'Enter') {
        event.preventDefault();
        searchLocation();
      }
    });
    currentButton.addEventListener('click', useCurrentLocation);

    if (initialPair) {
      applyCoordinates(initialPair.latitude, initialPair.longitude, { pan: false });
    } else {
      if (coordinatesResolvedField) coordinatesResolvedField.value = 'False';
      updateRadiusCircle(initialCenter[0], initialCenter[1]);
    }

    window.setTimeout(function () {
      map.invalidateSize();
    }, 250);
  }

  ready(function () {
    document
      .querySelectorAll('input[name$="latitude_longitude"]')
      .forEach(setupLocationPicker);
  });
})();
