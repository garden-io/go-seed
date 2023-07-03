#!/bin/bash

# Check the number of arguments
if [ $# -ne 1 ]; then
  echo "Usage: ./create-project.sh <template-name>"
  exit 1
fi

template_name=$1
repo_url="https://github.com/garden-io/garden-seeds.git"
clone_dir="/tmp/garden-seeds"

# Clone the repository
git clone $repo_url $clone_dir

# Check if the template exists
template_dir="$clone_dir/languages/$template_name"
if [ ! -d "$template_dir" ]; then
  echo "Template '$template_name' not found."
  exit 1
fi

# Navigate to the template directory
cd "$template_dir"

# Run Cookiecutter
cookiecutter .

# Cleanup: Remove the cloned repository
rm -rf $clone_dir
