class GuestUser
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def id
    nil
  end
end 