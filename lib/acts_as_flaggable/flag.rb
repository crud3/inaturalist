class Flag < ActiveRecord::Base
  SPAM = "spam"
  INAPPROPRIATE = "inappropriate"
  COPYRIGHT_INFRINGEMENT = "copyright infringement"
  FLAGS = [
    SPAM,
    INAPPROPRIATE,
    COPYRIGHT_INFRINGEMENT
  ]
  belongs_to :flaggable, polymorphic: true
  belongs_to :flaggable_user, class_name: "User", foreign_key: "flaggable_user_id"

  has_subscribers :to => {
    :comments => {:notification => "activity", :include_owner => true},
  }
  notifies_subscribers_of :self, :notification => "activity", :include_owner => true,
    :on => :update,
    :queue_if => Proc.new {|flag|
      !flag.new_record? && flag.comment_changed?
    }
  auto_subscribes :resolver, :on => :update, :if => Proc.new {|record, resource|
    record.resolved_changed? && !record.resolver.blank? && 
      !record.resolver.subscriptions.where(:resource_type => "Flag", :resource_id => record.id).exists?
  }

  blockable_by lambda {|flag| flag.flaggable.try(:user_id) }, on: :create
  
  # NOTE: Flags belong to a user
  belongs_to :user
  belongs_to :resolver, :class_name => 'User', :foreign_key => 'resolver_id'
  has_many :comments, :as => :parent, :dependent => :destroy

  before_save :set_resolved_at
  before_create :set_flaggable_user_id

  after_create :notify_flaggable_on_create
  after_update :notify_flaggable_on_update
  after_destroy :notify_flaggable_on_destroy
  
  # A user can flag a specific flaggable with a specific flag once
  validates_length_of :flag, :in => 3..256, :allow_blank => false
  validates_length_of :comment, :maximum => 256, :allow_blank => true
  validates_uniqueness_of :user_id, :scope => [:flaggable_id, :flaggable_type, :flag], :message => "has already flagged that item."
  validate :flaggable_type_valid
  
  def flaggable_type_valid
    if FlagsController::FLAG_MODELS.include?(flaggable_type)
      true
    else
      errors.add(:flaggable_type, "can't be flagged")
    end
  end

  def notify_flaggable_on_create
    if flaggable && flaggable.respond_to?(:flagged_with)
      flaggable.flagged_with(self, :action => "created")
    end
    true
  end

  def notify_flaggable_on_update
    if flaggable && flaggable.respond_to?(:flagged_with) && resolved_changed? && resolved?
      flaggable.flagged_with(self, :action => "resolved")
    end
    true
  end

  def notify_flaggable_on_destroy
    if flaggable && flaggable.respond_to?(:flagged_with)
      flaggable.flagged_with(self, :action => "destroyed")
    end
    true
  end

  def is_akismet_spam_flag?
    user_id == 0 && flag == Flag::SPAM
  end

  def as_indexed_json
    {
      id: id,
      flag: flag,
      comment: comment,
      user_id: user_id,
      resolver_id: user_id,
      resolved: resolved,
      created_at: created_at,
      updated_at: updated_at
    }
  end

  # Helper class method to lookup all flags assigned
  # to all flaggable types for a given user.
  def self.find_flags_by_user(user)
    find(:all,
      :conditions => ["user_id = ?", user.id],
      :order => "created_at DESC"
    )
  end
  
  # Helper class method to look up all flags for 
  # flaggable class name and flaggable id.
  def self.find_flags_for_flaggable(flaggable_str, flaggable_id)
    find(:all,
      :conditions => ["flaggable_type = ? and flaggable_id = ?", flaggable_str, flaggable_id],
      :order => "created_at DESC"
    )
  end

  # Helper class method to look up a flaggable object
  # given the flaggable class name and id 
  def self.find_flaggable(flaggable_str, flaggable_id)
    flaggable_str.constantize.find(flaggable_id)
  end
  
  def flagged_object
    eval("#{flaggable_type}.find(#{flaggable_id})")
  end

  def set_resolved_at
    if resolved_changed? && resolved
      self.resolved_at = Time.now
    elsif resolved_changed?
      self.resolved_at = nil
    end
    true
  end

  def get_flaggable_user
    case flaggable_type
    when "User" then flaggable
    when "Message" then flaggable.from_user
    else
      k, reflection = flaggable.class.reflections.detect{|r| r[1].class_name == "User" && r[1].macro == :belongs_to }
      if reflection
        flaggable.send( k )
      else
        nil
      end
    end
  end

  def set_flaggable_user_id
    return true unless flaggable
    if u = get_flaggable_user
      self.flaggable_user_id = u.id
    end
    true
  end
end
