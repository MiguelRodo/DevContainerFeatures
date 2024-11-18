  apt-get update -y
  
  # Ensure jq is installed
  if ! command -v jq &> /dev/null; then
    echo "jq could not be found, installing jq..."
    apt-get install -y jq
  fi
  