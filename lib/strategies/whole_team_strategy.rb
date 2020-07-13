require_relative 'base'

# Split your app into teams, this strategy figures out which team
# the creator is from and:
# - assigns the creator of the MR as assignee
# - adds an approval rule with the creator's team as approvers
#   (gotten from @reviewer_pool's team_handle)
# - removes the default approval rule (everybody can approve)
# - write a comment to alert the reviewers
class WholeTeamStrategy < BaseStrategy
  def pick_reviewers(pr_creator: )
    [pr_creator]
  end

  def assign!
    @pull_request.set_assigner!(reviewer)

    @pull_request.set_approval_rule!(approvers)
    @pull_request.remove_default_approval_rule!

    @pull_request.add_comment!(message)
  end

  private

  def approvers
    creator_team = @reviewer_pool.detect { |team| Array(team["members"]).include?(@pull_request.creator) }
    Array(creator_team&.fetch("team_handle", nil))
  end

  def message
    "Thank you @#{@pull_request.creator} for your contribution! #{approvers.map { |approver| "@#{approver}" }.join(", ")} it's now your turn to review."
  end
end
