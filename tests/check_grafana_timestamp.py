#!/usr/bin/env python3
"""Wait for the Grafana telemetry endpoint to return data newer than runner start time."""

import argparse
import json
import sys
import time
from datetime import datetime
from typing import Any
from urllib.error import URLError
from urllib.request import urlopen

TIMEOUT_SECONDS = 20
POLL_INTERVAL_SECONDS = 1
REQUEST_TIMEOUT_SECONDS = 5


def parse_timestamp(value: Any) -> datetime:
    if not isinstance(value, str):
        raise ValueError("timestamp must be an ISO-8601 string")

    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    parsed = datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        raise ValueError("timestamp must include a timezone")
    return parsed


def fetch_latest_timestamp(url: str, timeout: float) -> tuple[datetime, str]:
    with urlopen(url, timeout=timeout) as response:
        records = json.loads(response.read().decode("utf-8"))

    if not isinstance(records, list) or not records:
        raise ValueError("endpoint response must be a non-empty JSON array")

    timestamps = []
    for record in records:
        if not isinstance(record, dict) or "timestamp" not in record:
            raise ValueError("every endpoint record must contain a timestamp")
        timestamp_text = record["timestamp"]
        timestamps.append((parse_timestamp(timestamp_text), timestamp_text))

    return max(timestamps, key=lambda item: item[0])


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Pass when the newest telemetry timestamp is newer than the action runner time "
            "within 20 seconds."
        )
    )
    parser.add_argument("url", help="grafana_json_export_url endpoint")
    parser.add_argument(
        "action_runner_time",
        help="ISO-8601 action runner timestamp, including a timezone (for example, 2026-10-26T11:00:00Z)",
    )
    args = parser.parse_args()

    try:
        action_runner_time = parse_timestamp(args.action_runner_time)
    except ValueError as error:
        parser.error(f"invalid action runner time: {error}")

    deadline = time.monotonic() + TIMEOUT_SECONDS
    last_result = "no response received"

    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break

        try:
            latest, latest_text = fetch_latest_timestamp(
                args.url, min(REQUEST_TIMEOUT_SECONDS, remaining)
            )
            if time.monotonic() >= deadline:
                last_result = "response arrived after the timeout"
                break
            if latest > action_runner_time:
                print(
                    f"PASS: latest timestamp {latest_text} is newer than "
                    f"action runner time {args.action_runner_time}"
                )
                return 0
            last_result = (
                f"latest timestamp {latest_text} is not newer than action runner time "
                f"{args.action_runner_time}"
            )
        except (OSError, URLError, json.JSONDecodeError, ValueError) as error:
            last_result = str(error)

        remaining = deadline - time.monotonic()
        if remaining > 0:
            time.sleep(min(POLL_INTERVAL_SECONDS, remaining))

    print(
        f"FAIL: timed out after {TIMEOUT_SECONDS} seconds; {last_result}",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
