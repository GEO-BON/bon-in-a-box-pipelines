import json
import re
from datetime import datetime, timezone
from typing import Any, Dict, Optional

def parse_json_from_output(output_str: str) -> Dict[str, Any]:
    lines = output_str.split("\n")
    parsing_json = False
    json_str = ""
    for l in reversed(lines):
        if not parsing_json:
            if l.endswith("}"):
                parsing_json = True
        json_str = l + json_str
        if l.startswith("{"):
            break
    return json.loads(json_str)


def parse_date(date_str: str) -> datetime:
    if re.match(r"^\d{4}-\d{1,2}-\d{1,2}$", date_str):
        return datetime.strptime(date_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    if re.match(r"^\d{4}\d{2}\d{2}$", date_str):
        return datetime.strptime(date_str, "%Y%m%d").replace(tzinfo=timezone.utc)
    if re.match(r"^\d{4}-\d{1,2}-\d{1,2}T\d{1,2}:\d{1,2}:\d{1,2}Z$", date_str):
        return datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    try:
        return datetime.strptime(date_str, "%Y%m%dT%H%M%S").replace(tzinfo=timezone.utc)
    except ValueError:
        pass
    return datetime.strptime(date_str, "%Y-%m-%dT%H:%M:%S.%fZ").replace(tzinfo=timezone.utc)

_DATE_REGEX = re.compile(r"(?P<date>\d{8}T\d{6}|\d{8}|\d{4}-\d{2}-\d{2})")

def extract_date_from_filename(filename: str) -> Optional[datetime]:
    match = _DATE_REGEX.search(filename)
    if match:
        try:
            return parse_date(match.group("date"))
        except ValueError:
            pass
    return None