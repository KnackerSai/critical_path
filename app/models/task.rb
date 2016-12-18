class Task < ActiveRecord::Base
  #validates :text, presence: true, length: {maximum: 250}

  #has_many :sources, through: :links
  #has_many :dependecies, through: :links
end
