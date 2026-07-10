#!/bin/bash

# Function to update file contents by replacing text references
# Usage: update_file_contents <search_term> <replacement_term> [directory]
update_file_contents() {
    local search_term="$1"
    local replacement_term="$2"
    local target_dir="${3:-.}"
    
    echo "Updating file contents: replacing '$search_term' with '$replacement_term' in '$target_dir'..."
    
    # Find text files and update their contents
    # Exclude binary files, .git directories, and common build/cache directories
    find "$target_dir" -type f \
        -not -path "*/\.*" \
        -not -path "*/node_modules/*" \
        -not -path "*/target/*" \
        -not -path "*/build/*" \
        -not -path "*/.terraform/*" \
        -exec file {} \; | grep -E "(text|ASCII)" | cut -d: -f1 | while read -r file; do
        
        # Check if file contains the search term
        if grep -q "$search_term" "$file" 2>/dev/null; then
            echo "Updating references in: $file"
            # Use sed to replace all occurrences in the file
            sed -i "s|${search_term}|${replacement_term}|g" "$file"
        fi
    done
}

# Generic function to rename files and folders by replacing text in their names
# Usage: rename_files <search_term> <replacement_term> [directory] [update_contents]
rename_files() {
    local search_term="$1"
    local replacement_term="$2"
    local target_dir="${3:-.}"  # Default to current directory if not specified
    local update_contents="${4:-true}"  # Default to true if not specified
    
    # Validate input parameters
    if [[ -z "$search_term" || -z "$replacement_term" ]]; then
        echo "Usage: rename_files <search_term> <replacement_term> [directory] [update_contents]"
        echo "Example: rename_files foundation foundation /path/to/directory true"
        return 1
    fi
    
    if [[ ! -d "$target_dir" ]]; then
        echo "Error: Directory '$target_dir' does not exist"
        return 1
    fi
    
    echo "Searching for files and folders containing '$search_term' in '$target_dir'..."
    
    # First, update file contents if requested
    if [[ "$update_contents" == "true" ]]; then
        update_file_contents "$search_term" "$replacement_term" "$target_dir"
    fi
    
    # Find all files and directories containing the search term
    find "$target_dir" -name "*${search_term}*" -type f -o -name "*${search_term}*" -type d | while read -r file; do
        # Get the directory and basename
        dir=$(dirname "$file")
        base=$(basename "$file")
        
        # Replace search term with replacement term in the filename
        new_name=$(echo "$base" | sed "s/${search_term}/${replacement_term}/g")
        
        # Only rename if the name actually changed
        if [[ "$base" != "$new_name" ]]; then
            new_path="$dir/$new_name"
            echo "Renaming: $file -> $new_path"
            mv "$file" "$new_path"
        fi
    done
    
    echo "Rename operation completed."
}

# Example usage (uncomment to use):
# rename_files "foundation" "foundation"
# rename_files "foundation" "foundation" "/specific/directory" true
# rename_files "old_name" "new_name" "/specific/directory" false  # Skip content updates
# update_file_contents "foundation" "foundation" "/specific/directory"  # Only update contents


