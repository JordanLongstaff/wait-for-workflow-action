#!/bin/bash

workflow_id="$WORKFLOW_ID" # Id of the target workflow

# Set the maximum waiting time (in minutes) and initialize the counter
max_wait_minutes="$MAX_WAIT_MINUTES"
counter=0

# Get the current time in ISO 8601 format
current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# If REF is empty, use github.ref
if [ -z "$REF" ]; then
  REF="${GITHUB_REF}"
else
  REF="refs/heads/$REF"
fi

# Wait for the workflow to be triggered
while true; do
  run_id=$(curl -s -H "Accept: application/vnd.github+json" -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${ORG_NAME}/${REPO_NAME}/actions/workflows/${workflow_id}/runs" | \
    jq -r --arg ref "$(echo "$REF" | sed 's/refs\/heads\///')" --arg current_time "$current_time" \
    '.workflow_runs[] | select(.head_branch == $ref and .created_at >= $current_time) | .id')
  if [ -n "$run_id" ]; then
    break
  fi

  # Increment the counter and check if the maximum waiting time is reached
  counter=$((counter + 1))
  if [ $((counter * 30)) -ge $((max_wait_minutes * 60)) ]; then
    echo "Maximum waiting time for the workflow to be triggered has been reached. Exiting."
    exit 1
  fi

  echo "Waiting for the workflow to be triggered..."
  sleep 30
done

# Wait for the triggered workflow to complete and check its conclusion
while true; do
  run_data=$(curl -s -H "Accept: application/vnd.github+json" -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${ORG_NAME}/${REPO_NAME}/actions/runs/$run_id")
  status=$(echo "$run_data" | jq -r '.status')

  if [ "$status" = "completed" ]; then
    conclusion=$(echo "$run_data" | jq -r '.conclusion')
    if [ "$conclusion" != "success" ]; then
      echo "The workflow has not completed successfully. Exiting."
      exit 1
    else
      echo "The workflow completed successfully! Exiting."
      break
    fi
  fi
  echo "Waiting for the workflow to complete..."
  sleep 30
done
