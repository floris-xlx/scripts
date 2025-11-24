import sys
import os
import fnmatch
from datetime import datetime


COLOR_DEFAULT = "37"
COLOR_FOLDER = "36"
EXTENSION_TO_COLOR = {
    ".txt": "32",
    ".exe": "31",
    ".bat": "33",
    ".py": "94",
    ".rs": "91",
    ".js": "93",
    ".ts": "34",
    ".tsx": "34",
    ".jsx": "34",
    ".c": "31",
    ".mp4": "96",
    ".md": "94",
    ".json": "93",
    ".sql": "94",
}


def colorize(text: str, color_code: str) -> str:
    return f"\x1b[{color_code}m{text}\x1b[0m"


def parse_pattern(arg: str | None) -> tuple[str, str, bool]:
    """
    Returns (base_dir, basename_pattern, arg_provided)
    """
    if not arg:
        return ".", "*", False
    # Support patterns like subdir\*.py (Windows)
    base_dir = os.path.dirname(arg) or "."
    basename_pattern = os.path.basename(arg) or "*"
    return base_dir, basename_pattern, True


def list_directory(base_dir: str, basename_pattern: str, arg_provided: bool):
    try:
        entries = list(os.scandir(base_dir))
    except FileNotFoundError:
        print(f'Directory not found: "{base_dir}"')
        return

    # Determine if we should fallback to "*": replicate batch's "no file matches" behavior
    file_match_count = sum(
        1
        for e in entries
        if e.is_file()
        and fnmatch.fnmatch(e.name, basename_pattern)
    )
    if arg_provided and file_match_count == 0:
        basename_pattern = "*"

    # Build records
    records = []
    for e in entries:
        if not fnmatch.fnmatch(e.name, basename_pattern):
            continue

        is_dir = e.is_dir()
        name_display = f"{e.name}\\" if is_dir else e.name

        if is_dir:
            size_str = "--"
            date_str = "--"
            time_str = "--"
            color_code = COLOR_FOLDER
            ext = ""
        else:
            try:
                stat = e.stat()
                size_str = str(stat.st_size)
                dt = datetime.fromtimestamp(stat.st_mtime)
                mon = dt.strftime("%b")
                dd = str(dt.day)  # no leading zero
                hh = str(dt.hour)  # no leading zero
                mm = f"{dt.minute:02d}"
                date_str = f"{mon} {dd},"
                time_str = f"{hh}{mm}"
            except OSError:
                size_str = "--"
                date_str = "--"
                time_str = "--"
                dt = None

            _, ext = os.path.splitext(e.name)
            color_code = EXTENSION_TO_COLOR.get(ext.lower(), COLOR_DEFAULT)

        records.append(
            {
                "name": e.name,
                "name_display": name_display,
                "is_dir": is_dir,
                "size": size_str,
                "date": date_str,
                "time": time_str,
                "color": color_code,
                "ext": ext.lower() if not is_dir else "",
            }
        )

    # Sort by extension (directories have empty ext) to mirror /o:e behavior
    records.sort(key=lambda r: (r["ext"], r["name"].lower()))

    # Compute name column width
    max_name_len = 0
    for r in records:
        ln = len(r["name_display"])
        if ln > max_name_len:
            max_name_len = ln
    max_name_len += 2  # padding like original

    # Print header
    # Widths: Size(10), Date(12), Time(8), Name(variable)
    print("Size      ", end="")
    print("Date       ", end="")
    print("Time    ", end="")
    print("Name")

    for r in records:
        name_colored = colorize(r["name_display"], r["color"])
        # Left-align to mimic original spacing
        size_part = f"{r['size']:<10}"
        date_part = f"{r['date']:<12}"
        time_part = f"{r['time']:<8}"
        name_part = f"{name_colored}{' ' * (max_name_len - len(r['name_display']))}"
        print(f"{size_part}{date_part}{time_part}{name_part}")


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    base_dir, basename_pattern, arg_provided = parse_pattern(arg)
    list_directory(base_dir, basename_pattern, arg_provided)


if __name__ == "__main__":
    main()


