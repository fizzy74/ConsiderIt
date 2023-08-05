class Comment < ApplicationRecord
  include Moderatable, Notifier

  class_attribute :my_public_fields
  self.my_public_fields = [:id, :body, :user_id, :created_at, :point_id, :moderation_status, :subdomain_id, :hide_name ]

  scope :public_fields, -> {select(self.my_public_fields)}
  scope :named, -> {where( :hide_name => false )}
  
  validates_presence_of :body
  validates_presence_of :user
    
  belongs_to :user
  belongs_to :point

  has_one :proposal, :through => :point

  acts_as_tenant :subdomain


  before_save do 
    self.body = sanitize_helper(self.body) if self.body
  end


  def as_json(options={})
    options[:only] ||= Comment.my_public_fields
    result = super(options)
    make_key(result, 'comment')

    anonymize_everything = current_subdomain.customization_json['anonymize_everything']

    # If anonymous, hide user id
    if (anonymize_everything || self.hide_name) && (current_user.nil? || current_user.id != self.user_id)
      result['user_id'] = User.anonymized_id(result['user_id'])
    end

    stubify_field(result, 'user')
    stubify_field(result, 'point')
    result
  end

  def proposal
    point.proposal
  end

  # Fetches all comments associated with this Point. 
  def self.comments_for_point(point)
    if current_subdomain.moderation_policy == 1
      moderation_status_check = 'moderation_status=1'
    else 
      moderation_status_check = '(moderation_status IS NULL OR moderation_status=1)'
    end
    
    comments = {
      :comments => point.comments.where("#{moderation_status_check} OR user_id=#{current_user.id}"),
      :key => "/comments/#{point.id}"
    }


    comments

  end


  # Fetches all comments associated with this Point. 
  def self.comments_for_forum(forum=nil)
    forum ||= current_subdomain
    if forum.moderation_policy == 1
      moderation_status_check = 'moderation_status=1'
    else 
      moderation_status_check = '(moderation_status IS NULL OR moderation_status=1)'
    end
    
    comments = {
      :comments => forum.comments.where("#{moderation_status_check} OR user_id=#{current_user.id}"),
      :key => "/all_comments"
    }


    comments

  end


end
