import os
from tqdm import tqdm
from concurrent.futures import ThreadPoolExecutor

class AnsiColors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    RESET = '\033[0m'

def create_folder(folder_name):
    folder_path = os.path.join(os.path.abspath(os.sep), folder_name)
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)
        print(f"{AnsiColors.GREEN}Created {folder_name} folder at: {folder_path}{AnsiColors.RESET}")
    else:
        print(f"{AnsiColors.YELLOW}{folder_name.capitalize()} folder already exists at: {folder_path}{AnsiColors.RESET}")
    return folder_path

def print_free_space(directory):
    statvfs = os.statvfs(directory)
    free_space = statvfs.f_frsize * statvfs.f_bavail
    print(f"{AnsiColors.GREEN}Free space in '{directory}': {free_space} bytes{AnsiColors.RESET}")

def process_file(file_name, root_dir, folders, file_extensions):
    file_path = os.path.join(root_dir, file_name)
    if not os.path.isfile(file_path):
        print(f"{AnsiColors.RED}'{file_name}' is not a file, skipping.{AnsiColors.RESET}")
        return

    file_extension = os.path.splitext(file_name)[1].lower()
    for category, extensions in file_extensions.items():
        if file_extension in extensions:
            try:
                os.rename(file_path, os.path.join(folders[category], file_name))
                print(f"{AnsiColors.GREEN}Moved file '{file_name}' to '{folders[category]}'{AnsiColors.RESET}")
            except Exception as e:
                print(f"{AnsiColors.RED}Error moving file '{file_name}': {e}{AnsiColors.RESET}")
            return

    print(f"{AnsiColors.YELLOW}File '{file_name}' does not match any known category, skipping.{AnsiColors.RESET}")

def sort_files_into_folders():
    root_dir = '.'
    folder_names = ['videos', 'images', 'zip', 'documents', 'audio', 'executable', 'data', 'code', 'fonts']
    folders = {name: create_folder(name) for name in folder_names}

    file_extensions = {
        'videos': ['.mp4', '.mov', '.m3u8', '.mkv', '.avi', '.wmv', '.flv', '.webm', '.mpg', '.mpeg'],
        'images': ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.svg', '.webp'],
        'zip': ['.zip', '.rar', '.tar', '.gz'],
        'documents': ['.pdf', '.docx', '.txt', '.md','.aspx', '.doc', '.pptx', '.xls', '.xlsx'],
        'audio': ['.mp3', '.wav'],
        'executable': ['.exe', '.apk', '.bat', '.sh', '.msi'],
        'data': ['.csv', '.json', '.xml', '.yml', '.yaml'],
        'code': ['.py', '.js', '.html'],
        'fonts': ['.ttf', '.otf', '.woff', '.woff2'],
    }

    try:
        files = os.listdir(root_dir)
    except OSError as e:
        print(f"{AnsiColors.RED}Error accessing directory '{root_dir}': {e}{AnsiColors.RESET}")
        return

    def process_and_print(file_name):
        process_file(file_name, root_dir, folders, file_extensions)
        for folder in folders.values():
            print_free_space(folder)

    with ThreadPoolExecutor() as executor:
        list(tqdm(executor.map(process_and_print, files), desc="Processing files", unit="file", total=len(files)))

if __name__ == "__main__":
    sort_files_into_folders()
