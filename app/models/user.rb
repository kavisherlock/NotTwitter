include SessionsHelper
# == Schema Information
#
# Table name: users
#
#  id                   :integer          not null, primary key
#  name                 :string
#  email                :string
#  handle               :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
class User < ApplicationRecord
  has_many :dweeds, dependent: :destroy
  has_many :active_relationships, class_name: 'Relationship',
                                  foreign_key: 'follower_id',
                                  dependent: :destroy
  has_many :passive_relationships, class_name:  'Relationship',
                                   foreign_key: 'followee_id',
                                   dependent:   :destroy
  has_many :following, through: :active_relationships, source: :followee
  has_many :followers, through: :passive_relationships, source: :follower

  attr_accessor :remember_token
  before_save { self.email = email.downcase }

  validates :name, presence: true, length: { maximum: 127 }

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMAIL_REGEX },
                    uniqueness: { case_sensitive: false,
                                  message: 'duplicate email' }

  validates :handle, presence: true,
                     length: { maximum: 15 },
                     uniqueness: { case_sensitive: false,
                                   message: 'duplicate handle' }

  has_secure_password
  validates :password, length: { minimum: 6 }, allow_blank: true

  # Returns the hash digest of the given string.
  def self.digest(string)
    cost = if ActiveModel::SecurePassword.min_cost
             BCrypt::Engine::MIN_COST
           else
             BCrypt::Engine.cost
           end
    BCrypt::Password.create(string, cost: cost)
  end

  # Returns a random token.
  def self.new_token
    SecureRandom.urlsafe_base64
  end

  # Remembers a user in the database for use in persistent sessions.
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # Returns true if the given token matches the digest.
  def authenticated?(remember_token)
    log_out if logged_in?
    BCrypt::Password.new(remember_digest).is_password?(remember_token)
  end

  # Forgets a user.
  def forget
    update_attribute(:remember_digest, nil)
  end

  # Defines a news feed.
  def feed
    following_ids = "SELECT followee_id FROM relationships
                     WHERE  follower_id = :user_id"
    Dweed.where("user_id IN (#{following_ids}) OR user_id = :user_id",
                user_id: id)
  end

  # Follows a user.
  def follow(followee)
    active_relationships.create(followee_id: followee.id)
  end

  # Unfollows a user.
  def unfollow(followee)
    active_relationships.find_by(followee_id: followee.id).destroy
  end

  # Returns true if the current user is following the other user.
  def following?(other_user)
    following.include?(other_user)
  end
end
