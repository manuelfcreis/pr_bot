class BaseStrategy
  def initialize(reviewer_pool:, pull_request: )
    @reviewer_pool = reviewer_pool
    @pull_request = pull_request
  end

  def assign!
    @pull_request.set_assigner!(reviewer)
    @pull_request.add_comment!(message)
  end

  private

  def message
    "Thank you @#{@pull_request.creator} for your contribution! I have determined that @#{reviewer} shall review your code"
  end

  def reviewer
    @reviewer ||= pick_reviewers(pr_creator: @pull_request.creator).first
  end
end
