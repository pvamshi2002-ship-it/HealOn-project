import json
import re
from urllib.error import URLError
from urllib.parse import parse_qs, quote_plus, unquote, urlparse
from urllib.request import Request, urlopen


def extract_coordinates_from_map_url(value):
    text = (value or '').strip()
    if not text:
        return None

    decoded = unquote(resolve_map_url(text))
    patterns = [
        r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        r'[?&](?:q|query|ll)=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
        r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
        r'^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$',
    ]
    for pattern in patterns:
        match = re.search(pattern, decoded)
        if match:
            return match.group(1), match.group(2)

    parsed = urlparse(decoded)
    query = parse_qs(parsed.query)
    for key in ('q', 'query', 'll'):
        raw = query.get(key, [''])[0]
        match = re.search(r'(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)', raw)
        if match:
            return match.group(1), match.group(2)

    return None


def geocode_location_text(value):
    text = (value or '').strip()
    if not text:
        return None

    for candidate in location_lookup_candidates(text):
        coordinates = geocode_single_location_text(candidate)
        if coordinates:
            return coordinates
    return None


def location_lookup_candidates(text):
    normalized = re.sub(r'\bRd\b', 'Road', text, flags=re.IGNORECASE)
    normalized = re.sub(
        r'Kammagondahalli',
        'Kammagondanahalli',
        normalized,
        flags=re.IGNORECASE,
    )
    candidates = []
    for candidate in (text, normalized):
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    if re.fullmatch(r'\s*k\.?\s*g\.?\s*halli\s*', text, flags=re.IGNORECASE):
        candidates.extend([
            'Kammagondanahalli, Jalahalli West, Bengaluru, Karnataka 560015',
            'Jalahalli West, Bengaluru, Karnataka 560015',
        ])

    parts = [part.strip() for part in normalized.split(',') if part.strip()]
    for index in range(1, max(len(parts) - 1, 1)):
        candidate = ', '.join(parts[index:])
        if candidate and candidate not in candidates:
            candidates.append(candidate)

    return candidates


def geocode_single_location_text(text):
    url = f'https://nominatim.openstreetmap.org/search?q={quote_plus(text)}&format=json&limit=1'
    try:
        request = Request(
            url,
            headers={
                'User-Agent': 'HealOnAdminLocation/1.0',
                'Accept': 'application/json',
            },
        )
        with urlopen(request, timeout=8) as response:
            results = json.loads(response.read().decode('utf-8') or '[]')
    except (ValueError, URLError, json.JSONDecodeError):
        return None

    if not results:
        return None

    result = results[0]
    latitude = result.get('lat')
    longitude = result.get('lon')
    if latitude and longitude:
        return latitude, longitude
    return None


def resolve_map_url(value):
    text = (value or '').strip()
    parsed = urlparse(text)
    if parsed.netloc not in {'maps.app.goo.gl', 'goo.gl'}:
        return text

    try:
        request = Request(
            text,
            headers={
                'User-Agent': (
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36'
                )
            },
        )
        with urlopen(request, timeout=8) as response:
            return response.geturl()
    except (ValueError, URLError):
        return text
