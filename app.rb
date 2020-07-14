require 'bundler'
require 'json'
Bundler.require
Dotenv.load

require_relative "lib/strategies/list_strategy.rb"
require_relative "lib/strategies/teams_strategy.rb"
require_relative "lib/strategies/tiered_strategy.rb"
require_relative "lib/strategies/whole_team_strategy.rb"

set :bind, ENV['BIND'] || 'localhost'

# Required ENV vars:
#
# GITLAB_TOKEN: S0meToken
# GITLAB_ENDPOINT: https://your.gitlab.com/api/v4
# REVIEWER_POOL (simple strategy): ["user1", "user2", "user3"]
# REVIEWER_POOL (tiered strategy): [{"count": 2, "name": ["andruby","jeff","ron"]},{"count": 1, "names": ["defunkt","pjhyett"]}]
# REVIEWER_POOL (teams strategy): [{"captains": ["user1"], "members": ["user2", "user3"], "allow_out_of_team_reviews": false},{"captains": ["user4"], "members": ["user4", "user5"], "count": 1}]
# REVIEWER_POOL (mixed strategy): [{"strategy":"whole_team", "team_handle":"amazing-team", "members": ["user2", "user3"]},{"strategy":"teams","captains": ["user4"], "members": ["user4", "user5"], "count": 1, "allow_out_of_team_reviews": false}]
# PR_LABEL: for-review
#
# Optional ENV vars:
#
# STRATEGY: list OR tiered OR teams (defaults to simple)

class PullRequest
  attr_reader :strategy

  def initialize(payload, reviewer_pool:, label:)
    @payload = payload
    @label = label
    @reviewer_pool = reviewer_pool
    @strategy = strategy_class.new(reviewer_pool: reviewer_pool, pull_request: self)
  end

  def needs_assigning?
    # Already has an assignee
    return false if @payload["assignee"] || @payload["assignees"]

    # When adding label "for-review"
    label_changes = @payload.dig("changes", "labels")

    # No labels where changed
    return false unless label_changes

    # For gitlab, we don't check if someone was already
    return false if label_changes["previous"].detect { |label| label["title"] == @label }
    return true if label_changes["current"].detect { |label| label["title"] == @label }
  end

  def assign!
    @strategy.assign!
  end

  def set_assigner!(assignee_name)
    assignee_id = username_to_id(assignee_name)
    client.update_merge_request(project_id, merge_request_id, assignee_id: assignee_id)
  end

  def set_approval_rule!(approver_names)
    return if approver_names.empty?

    approver_ids = approver_names.map { |approver_name| group_name_to_id(approver_name) }
    payload = {name: approver_names.join("/"), approvals_required: 1, group_ids: approver_ids}
    client.post("/projects/#{project_id}/merge_requests/#{merge_request_id}/approval_rules", body: payload)
  end

  def remove_default_approval_rule!
    rules = client.get("/projects/#{project_id}/merge_requests/#{merge_request_id}/approval_rules")
    any_approver_rule = rules.find { |rule| rule.rule_type == "any_approver" }
    return unless any_approver_rule
    client.delete("/projects/#{project_id}/merge_requests/#{merge_request_id}/approval_rules/#{any_approver_rule.id}")
  end

  def add_comment!(message)
    client.create_merge_request_note(project_id, merge_request_id, message)
  end

  def creator
    @creator ||= begin
      author_id = @payload.dig("object_attributes", "author_id")
      client.user(author_id).username
    end
  end

  def username_to_id(username)
    client.users(username: username).first&.id
  end

  def group_name_to_id(group_name)
    client.groups.find { |group| group.full_path == group_name }&.id
  end

  private

  def strategy_class
    team = @reviewer_pool.find { |team| Array(team["members"]).include?(creator) }
    classified_strategy_name = (team&.fetch("strategy", "teams") || "teams").split("_").map(&:capitalize).join

    Object.const_get("#{classified_strategy_name}Strategy")
  end

  def project_id
    @payload.dig("project", "id")
  end

  def merge_request_id
    # URL's need the "internal" id
    @payload.dig("object_attributes", "iid")
  end

  def client
    @@client ||= Gitlab.client(endpoint: ENV['GITLAB_ENDPOINT'], private_token: ENV['GITLAB_TOKEN'])
  end
end

get '/status' do
  "ok"
end

post '/gitlab-mr' do
  payload = JSON.parse(request.body.read)

  # Write to STDOUT for debugging perpose
  puts "Incoming payload: #{payload.inspect}"

  pull_request = PullRequest.new(payload, reviewer_pool: JSON.parse(ENV['REVIEWER_POOL']), label: ENV['PR_LABEL'])
  if pull_request.needs_assigning?
    puts "Assigning PR from #{pull_request.creator}"
    pull_request.assign!
  else
    puts "No need to assign reviewers"
  end
end
