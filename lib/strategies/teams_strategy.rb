require_relative 'base'

# Split your app into teams, this strategy figures out which team
# the creator is from and assigns the captain and anthor team member
class TeamsStrategy < BaseStrategy
  def pick_reviewers(pr_creator: )
    team = team_for(pr_creator)

    # you can specify count on the whole pool or for each team separately
    default_num = 2
    reviewers_num = team ? team.fetch("count", default_num) : default_num

    if captain?(pr_creator)
      team["members"].sample(reviewers_num)
    elsif member?(pr_creator)
      captain = Array(team["captains"]).sample(1)
      [captain, (team["members"] - [pr_creator]).sample(reviewers_num - captain.size)].flatten
    else
      teams_not_excluded.sample(2).map { |t| all_for_team(t).sample(1) }.flatten
    end
  end

  private
  def team_for(user)
    @reviewer_pool.detect do |team|
      if captain?(user)
        Array(team["captains"]).include?(user)
      elsif member?(user)
        Array(team["members"]).include?(user)
      end
    end
  end

  def teams_not_excluded
    @reviewer_pool.reject { |team| team["excluded"] }
  end

  def captain?(user)
    @reviewer_pool.map { |team| team["captains"] }.flatten.include?(user)
  end

  def member?(user)
    @reviewer_pool.map { |team| team["members"] }.flatten.include?(user)
  end

  def all_for_team(team)
    team["members"] + Array(team["captains"])
  end
end
