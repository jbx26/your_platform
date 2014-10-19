# Example:
# 
#   Role.of(user).in(corporation).to_s    #  => "guest"
#   Role.of(user).in(corporation).guest?  #  => true
#   Role.find_all_by_user_and_group(user, corporation)
#
#   Role.of(user).for(page).to_s          #  => "admin"
#   Role.of(user).for(user).to_s          #  => "global_admin"
#
class Role
  
  def initialize(given_user, given_object)
    @user = given_user
    @object = given_object
  end
  
  # Example:
  # 
  #   Role.of(user).in(corporation).to_s  #  => "guest"
  #
  def self.of(given_user)
    self.new(given_user, nil)
  end

  # Example:
  # 
  #   Role.of(user).in(corporation).to_s  #  => "guest"
  #
  def in(given_object)
    @object = given_object
    return self
  end
  def for(given_object)
    self.in(given_object)
  end
  
  def user
    @user || raise('User not given, when trying to determine Role.')
  end
  
  def object
    @object || raise('Object not given, when trying to determine Role.')
  end
  def group
    @object || raise('Group not given, when trying to determine Role.')
  end
  
  #
  # Roles for groups
  #
  
  def current_member?
    member? && full_member?
  end
  
  def full_member?
    object.kind_of?(Group) && 
      (( ([group] + group.descendant_groups) & user.groups.find_all_by_flag(:full_members) ).count > 0)
  end
    
  def member?
    object.kind_of?(Group) && user.member_of?(object)
  end
  
  def guest?
    object.kind_of?(Group) && user.guest_of?(object)
  end
  
  def former_member?
    object.kind_of?(Group) && object.corporation? && user.former_member_of_corporation?(object)
  end
  
  #
  # Roles for structureables
  #
  
  def global_admin?
    user.global_admin?
  end

  def admin?
    global_admin? || object.admins_of_self_and_ancestors.include?(user)
  end
  
  def officer?
    global_admin? || object.officers_of_self_and_ancestors.include?(user)
  end
  
  
  # Example
  #   Role.of(user).for(page).to_s  # => 'admin'
  def to_s
    return 'global_admin' if global_admin?
    return 'admin' if admin?
    return 'officer' if officer?
    return 'full_member' if full_member?
    return 'member' if member?
    return 'guest' if guest?
    return 'former_member' if former_member?
    return ''
  end
  
  
  # The system allows to simulate a certain role when viewing an object.
  # This determines which simulations are allowed.
  # 
  def allowed_preview_roles
    return ['global_admin', 'admin', 'officer', 'user'] if global_admin?
    return ['admin', 'officer', 'user'] if admin?
    return ['officer', 'user'] if officer?
  end
  def allow_preview?
    # The preview makes sense for officers and above.
    # All above roles are also officer roles.
    officer?
  end
  
  # Finding administrated objects.
  #
  #   Role.of(user).select_objects_where_user_is_admin(objects)
  #   Role.of(user).administrated_users
  #
  def select_objects_where_user_is_admin(objects)
    objects & administrated_objects
  end
  def admin_groups
    user.groups.find_all_by_flag(:admins_parent)
  end
  def directly_administrated_objects
    admin_groups.collect { |g| g.parent_groups.first.parents.first } - [nil]
  end
  def directly_administrated_groups
    admin_groups.collect { |g| g.parent_groups.first.parent_groups.first } - [nil]
  end
  def administrated_objects
    directly_administrated_objects.collect { |o| o.descendants }.flatten
  end
  def administrated_users
    directly_administrated_groups.collect { |g| g.descendant_users }.flatten
  end
  
  
  # This finder method returns all global admins.
  #
  def self.global_admins
    Group.find_everyone_group.try(:find_admins) || []
  end
  
end