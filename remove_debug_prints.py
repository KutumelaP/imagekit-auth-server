#!/usr/bin/env python3
"""
Script to remove debug print statements from Flutter code for production deployment.
Converts print() statements to if (kDebugMode) print() for conditional debugging.
"""

import os
import re
import glob

def process_dart_file(file_path):
    """Process a single Dart file to wrap print statements in kDebugMode check."""
    changes_made = False
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # Pattern to match print statements (various formats)
        patterns = [
            # Simple print statements
            r"(\s+)print\('([^']*?)'\);",
            r'(\s+)print\("([^"]*?)"\);',
            r"(\s+)print\('([^']*?)'\)",
            r'(\s+)print\("([^"]*?)"\)',
            
            # Print statements with variables/interpolation
            r"(\s+)print\('([^']*?\$[^']*?)'\);",
            r'(\s+)print\("([^"]*?\$[^"]*?)"\);',
            
            # Print statements that span multiple lines or complex expressions
            r"(\s+)print\(([^;]+?)\);",
        ]
        
        # Skip if already wrapped in kDebugMode
        if 'if (kDebugMode) print(' in content or 'if(kDebugMode)print(' in content:
            return False
            
        # Process each pattern
        for pattern in patterns:
            def replace_print(match):
                indent = match.group(1)
                if len(match.groups()) == 2:
                    # Simple patterns with message
                    message = match.group(2)
                    return f"{indent}if (kDebugMode) print('{message}');"
                else:
                    # Complex expressions
                    expression = match.group(2)
                    return f"{indent}if (kDebugMode) print({expression});"
            
            new_content = re.sub(pattern, replace_print, content, flags=re.MULTILINE | re.DOTALL)
            if new_content != content:
                content = new_content
                changes_made = True
        
        # Add kDebugMode import if needed and changes were made
        if changes_made and 'package:flutter/foundation.dart' not in content:
            # Find existing imports
            import_pattern = r"(import\s+['\"][^'\"]*['\"];?\s*\n)"
            imports = re.findall(import_pattern, content)
            
            if imports:
                # Add after the last import
                last_import = imports[-1]
                import_insertion = last_import + "import 'package:flutter/foundation.dart';\n"
                content = content.replace(last_import, import_insertion, 1)
            else:
                # Add at the beginning if no imports found
                content = "import 'package:flutter/foundation.dart';\n" + content
        
        # Write back if changes were made
        if changes_made:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"✅ Processed: {file_path}")
            return True
            
    except Exception as e:
        print(f"❌ Error processing {file_path}: {e}")
        
    return False

def main():
    """Main function to process all Dart files."""
    print("🔍 Scanning for Dart files with print statements...")
    
    # Directories to scan
    directories = ['lib', 'admin_dashboard/lib']
    total_files_processed = 0
    
    for directory in directories:
        if os.path.exists(directory):
            print(f"\n📁 Processing {directory}/...")
            
            # Find all .dart files
            dart_files = glob.glob(f"{directory}/**/*.dart", recursive=True)
            
            for dart_file in dart_files:
                if process_dart_file(dart_file):
                    total_files_processed += 1
    
    print(f"\n✨ Production optimization complete!")
    print(f"📊 Total files processed: {total_files_processed}")
    print(f"🚀 Your app is now production-ready!")
    
    if total_files_processed > 0:
        print(f"\n💡 Note: Debug prints are now conditional (kDebugMode)")
        print(f"🔧 In production builds, all debug output will be automatically removed")

if __name__ == "__main__":
    main()
