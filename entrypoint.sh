#!/bin/bash
set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
  echo "Set the GITHUB_REPOSITORY env variable."
  exit 1
fi

if [[ -z "$GITHUB_EVENT_PATH" ]]; then
  echo "Set the GITHUB_EVENT_PATH env variable."
  exit 1
fi

needsOneReview=$NEEDS_ONE_REVIEW
if [[ -z "$needsOneReview" ]]; then
  echo "Please set the NEEDS_ONE_REVIEW env variable."
  exit 1
fi

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
state=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

update_label() {
  # https://developer.github.com/v3/pulls/reviews/#list-reviews-on-a-pull-request
  body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/pulls/${number}/reviews?per_page=100")
  reviews=$(echo "$body" | jq --raw-output '.[] | {state: .state} | @base64')

  approvals=0

  for r in $reviews; do
    review="$(echo "$r" | base64 -d)"
    rState=$(echo "$review" | jq --raw-output '.state')

    if [[ "$rState" == "APPROVED" ]]; then
      approvals=$((approvals+1))
    fi

    echo "${approvals}/${APPROVALS} approvals"

    if [[ "$approvals" == "$APPROVALS" ]]; then
      echo "Labeling pull request"

      curl -sSL \
        -H "${AUTH_HEADER}" \
        -H "${API_HEADER}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"labels\":[\"${needsOneReview}\"]}" \
        "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels"

      else
          curl -sSL \
            -H "${AUTH_HEADER}" \
            -H "${API_HEADER}" \
            -X DELETE \
            "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${NEEDS_ONE_REVIEW}"
    fi
  done
}

if [[ "$action" == "submitted" ]] && [[ "$state" == "approved" ]]; then
  update_label
else
  echo "Ignoring event ${action}/${state}"
fi
