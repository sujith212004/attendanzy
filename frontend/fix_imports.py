
import os
import re

ROOT_DIR = r'c:\Users\vishn\OneDrive\Documents\attendanzy_with_backend\Attendanzy\frontend\lib'
PACKAGE_NAME = 'flutter_attendence_app'

def get_all_dart_files(root_dir):
    files_map = {} # filename -> relative_path_from_lib
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith('.dart'):
                # full path
                full_path = os.path.join(dirpath, filename)
                # relative path from lib
                rel_path = os.path.relpath(full_path, root_dir).replace('\\', '/')
                files_map[filename] = rel_path
    return files_map

def fix_imports():
    files_map = get_all_dart_files(ROOT_DIR)
    print(f"Found {len(files_map)} dart files.")
    
    # regex to capture import "..." or import '...'
    # also export
    # also part
    # We want to capture the string inside quotes.
    # Group 2 is the quote ref, Group 3 is the string.
    # Pattern: (import|export|part)\s+(['"])(.*?)\2
    
    import_pattern = re.compile(r'^\s*(import|export|part)\s+([\'"])(.*?)([\'"])', re.MULTILINE)

    for filename, rel_path in files_map.items():
        full_path = os.path.join(ROOT_DIR, rel_path)
        
        with open(full_path, 'r', encoding='utf-8') as f:
            content = f.read()
            
        def replace_match(match):
            directive = match.group(1)
            quote = match.group(2)
            uri = match.group(3)
            end_quote = match.group(4)
            
            # Extract filename from uri
            # If it's a package import not from our app, ignore
            if uri.startswith('package:') and not uri.startswith(f'package:{PACKAGE_NAME}/'):
                return match.group(0) # No change
            
            if uri.startswith('dart:'):
                return match.group(0) # No change

            # Get just the filename
            # Handle cases like: package:app/foo/bar.dart -> bar.dart
            # ../foo/bar.dart -> bar.dart
            base_name = os.path.basename(uri)
            
            # Lookup in files_map
            if base_name in files_map:
                new_rel_path = files_map[base_name]
                new_uri = f'package:{PACKAGE_NAME}/{new_rel_path}'
                return f'{directive} {quote}{new_uri}{end_quote}'
            
            # If not found, maybe it's a file that doesn't exist or is generated (like .g.dart)
            # If .g.dart, usually it's in the same folder.
            # We will leave it alone if not found in our map of .dart files.
            
            return match.group(0)

        # Process line by line to support the regex properly on lines
        lines = content.split('\n')
        new_lines = []
        modified = False
        
        for line in lines:
            # We verify if line contains import/export/part
            # Simple check first
            if line.strip().startswith(('import ', 'export ', 'part ')):
                new_line = import_pattern.sub(replace_match, line)
                if new_line != line:
                    modified = True
                    new_lines.append(new_line)
                else:
                    new_lines.append(line)
            else:
                new_lines.append(line)
                
        if modified:
            print(f"Updating {filename}...")
            with open(full_path, 'w', encoding='utf-8') as f:
                f.write('\n'.join(new_lines))

if __name__ == '__main__':
    fix_imports()
